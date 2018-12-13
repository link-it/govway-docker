#!/bin/bash -x 
exec 6<> /tmp/catalina_wrapper_debug.log
exec 2>&6 

USERID=${USERID:=1234}
GROUPID=${GROUPID:=${USERID}}

##########################################
# configurazione tomcat e deploy archivi #
##########################################
if ! id -u tomcat 
then
	groupadd -r -g ${GROUPID} tomcat 
	useradd -r --uid ${USERID} --create-home -g tomcat tomcat 

	mkdir -p ${GOVWAY_HOME}/etc ${GOVWAY_HOME}/pki ${GOVWAY_LOGDIR}

	##############################################
	## Preparazione database Hsql se installato ##
	##############################################
	if [ -d /opt/hsqldb-${HSQLDB_FULLVERSION} ]
	then
		mkdir -p ${GOVWAY_HOME}/database
        	if [ ! -f ${GOVWAY_HOME}/database/govwaydb.properties ]
	        then
			echo -n "INFO: Preparazione base dati HSQL ..."
        	        cat - <<EOSQLTOOL > /root/sqltool.rc
urlid govwayDB
url jdbc:hsqldb:file:${GOVWAY_HOME}/database/govwaydb;shutdown=true
username govway
password govway
transiso TRANSACTION_READ_COMMITTED
charset UTF-8
EOSQLTOOL
	                java -Dfile.encoding=UTF-8 -jar /opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/sqltool.jar --autoCommit govwayDB < /database/GovWay_setup.sql > /tmp/database_creation.log 2>&1
			echo " Ok."
	        fi
        	cp /opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/hsqldb.jar ${CATALINA_HOME}/lib/ 

	fi

	echo "CATALINA_OPTS=\"-XX:+UseConcMarkSweepGC -Dfile.encoding=UTF-8\"" > ${CATALINA_HOME}/bin/setenv.sh

	###################################################
	## Preparazione certificati per connettore https ##
	###################################################	
	export PKI_DIR=${GOVWAY_HOME}/pki
        FQDN="${FQDN:=test.govway.org}"
        if [ "$(echo ${PKI_DIR}/CA_*)" == "${PKI_DIR}"'/CA_*' ]
        then
		echo -n "INFO: Generazione certificati SSL ..."
                bash -x ${CATALINA_HOME}/bin/genera_certs.sh 2> /tmp/debug_certificate.log
		echo " Ok."
        fi

	###########################
	## configurazione tomcat ##
	##########################
	cat - >> ${CATALINA_HOME}/conf/catalina.properties <<EOPROPERTIES
$(env |grep -E 'GOVWAY')
user.language=it
user.country=IT
file.encoding=UTF-8
javax.net.debug=${JAVA_SSL_DEBUG}
tls.keystorepass=$(cat ${PKI_DIR}/stores/keystore_server.README.txt)
tls.keypass=$(cat ${PKI_DIR}/stores/keystore_server.README.txt)
EOPROPERTIES

	###############################
	### Aggiungo listener HTTPS ###
	###############################
        xsltproc ${CATALINA_HOME}/conf/ConnectorTLS_in_server.xslt ${CATALINA_HOME}/conf/server.xml > /var/tmp/server.xml
        mv /var/tmp/server.xml ${CATALINA_HOME}/conf/server.xml

	########################################
	### Rendo disponibili logs di tomcat ###
	########################################
	sed -i  -e "s#\${catalina.base}/logs#${GOVWAY_LOGDIR}/tomcat_logs#" ${CATALINA_HOME}/conf/logging.properties
	ln -s ${GOVWAY_LOGDIR}/tomcat_logs ${CATALINA_HOME}/logs
	
	####################
	## Deploy archivi ##
	####################
	rm -rf ${CATALINA_HOME}/webapps/* 
	cp /opt/govway-installer-${GOVWAY_FULLVERSION}/dist/cfg/*.properties ${GOVWAY_HOME}/etc 
	cp /opt/govway-installer-${GOVWAY_FULLVERSION}/dist/archivi/*.war ${CATALINA_HOME}/webapps 

fi



## Const
STARTUP_CHECK_FIRST_SLEEP_TIME=20
STARTUP_CHECK_SLEEP_TIME=5
STARTUP_CHECK_MAX_RETRY=60
STARTUP_CHECK_REGEX='GovWay/.* \(www.govway.org\) avviata correttamente in .* secondi'

DB_CHECK_FIRST_SLEEP_TIME=10
DB_CHECK_SLEEP_TIME=5
DB_CHECK_MAX_RETRY=60
DB_CHECK_CONNECT_TIMEOUT=2

WARMUP_CONNECT_TIMEOUT=2

## Var
SKIP_STARTUP_CHECK=${SKIP_STARTUP_CHECK:=FALSE}
SKIP_DB_CHECK=${SKIP_DB_CHECK:=TRUE}
SKIP_WARMUP=${SKIP_WARMUP:=TRUE}


if [ "${SKIP_DB_CHECK}" != "TRUE" ]
then
	echo "INFO: Attendo avvio della base dati ..."
	sleep ${DB_CHECK_FIRST_SLEEP_TIME}s
	DB_READY=1
	NUM_RETRY=0
	while [ ${DB_READY} -ne 0 -a ${NUM_RETRY} -le ${DB_CHECK_MAX_RETRY} ]
	do
		nc  -w "$DB_CHECK_CONNECT_TIMEOUT" -z "$GOVWAY_DATABASE_SERVER" "$GOVWAY_DATABASE_PORT"
	        DB_READY=$?
        	NUM_RETRY=$(( ${NUM_RETRY} + 1 ))
		if [  ${DB_READY} -ne 0 ]
		then
	        	echo "INFO: Attendo disponibilita' della base dati ..."
		        sleep ${DB_CHECK_SLEEP_TIME}s
		fi
	done
	if [  ${DB_READY} -ne 0 -a ${NUM_RETRY} -eq ${DB_CHECK_MAX_RETRY} ]
	then
		echo "FATAL: Base dati NON disponibile dopo $((${DB_CHECK_SLEEP_TIME=} * ${DB_CHECK_MAX_RETRY})) secondi  ... Uscita."
		exit 1
	fi
	echo "INFO: Base dati disponibile."
fi




# correggo i diritti
chown -R tomcat.tomcat ${GOVWAY_HOME} ${GOVWAY_LOGDIR} ${CATALINA_HOME}
export UMASK=0002
coproc TOMCAT { /usr/local/bin/gosu tomcat catalina.sh $@; }

## Main
if [ "${SKIP_STARTUP_CHECK}" != "TRUE" ]
then

	/bin/rm -f  /tmp/govway_ready
	echo "INFO: Attendo avvio di GovWay ..."
	sleep ${STARTUP_CHECK_FIRST_SLEEP_TIME}s
	GOVWAY_READY=1
	NUM_RETRY=0
	while [ ${GOVWAY_READY} -ne 0 -a ${NUM_RETRY} -lt ${STARTUP_CHECK_MAX_RETRY} ]
	do
		grep -qE "${STARTUP_CHECK_REGEX}" ${GOVWAY_LOGDIR}/govway_startup.log  2> /dev/null
		GOVWAY_READY=$?
		NUM_RETRY=$(( ${NUM_RETRY} + 1 ))
		if [  ${GOVWAY_READY} -ne 1 ]
                then
			echo "INFO: Attendo avvio di GovWay ..."
			sleep ${STARTUP_CHECK_SLEEP_TIME}s
		fi
	done

	if [ ${NUM_RETRY} -eq ${STARTUP_CHECK_MAX_RETRY} ]
	then
		echo "FATAL: GovWay NON avviato dopo $((${DB_CHECK_SLEEP_TIME=} * ${DB_CHECK_MAX_RETRY})) secondi ... Uscita"
		kill -15 ${TOMCAT_PID}
	else
		if [ "${SKIP_WARMUP}" != "TRUE" ]
		then
			PROBE_INVOCATIONS_TOTAL=3
			CONCURRENT_INVOCATION=FALSE
			CONCURRENT_PROBE_INVOCATIONS=10
			CURL_OPTIONS="--noproxy 127.0.0.1 -s -w %{http_code} --connect-timeout "${WARMUP_CONNECT_TIMEOUT}" --max-time 5"
			CURL_PROBE_URL="http://127.0.0.1:8080/govway/check"
		
			echo -n "INFO: Inizio riscaldamento ..."
			if [ "${CONCURRENT_INVOCATION}" != "TRUE" ]
			then
	                	curl ${CURL_OPTIONS} "${CURL_PROBE_URL}" >/tmp/govway_check.log
	        	        NUM_PROBE_INVOCATION=1
        	        	while [ ${NUM_PROBE_INVOCATION} -le ${PROBE_INVOCATIONS_TOTAL} ]
	        		do
	        	                curl ${CURL_OPTIONS} "${CURL_PROBE_URL}" >/tmp/govway_check.log
        	        	        NUM_PROBE_INVOCATION=$(( ${NUM_PROBE_INVOCATION} + 1 ))
	        	        done
			else
				NUM_CONCURRENT_INVOCATION=1
				INVOCATIONS_PIDS=
				while [ ${NUM_CONCURRENT_INVOCATION} -le ${CONCURRENT_PROBE_INVOCATIONS} ]
				do
					curl ${CURL_OPTIONS} "${CURL_PROBE_URL}" >/tmp/govway_check_${NUM_CONCURRENT_INVOCATION}.log 2>&1 &
					INVOCATIONS_PIDS="${INVOCATIONS_PIDS} $!"
					NUM_CONCURRENT_INVOCATION=$(( ${NUM_CONCURRENT_INVOCATION} + 1 ))
				done
				wait ${INVOCATIONS_PIDS}
				NUM_PROBE_INVOCATION=1
		        	while [ ${NUM_PROBE_INVOCATION} -le ${PROBE_INVOCATIONS_TOTAL} ]
				do
					NUM_CONCURRENT_INVOCATION=1
					INVOCATIONS_PIDS=
	        			while [ ${NUM_CONCURRENT_INVOCATION} -le ${CONCURRENT_PROBE_INVOCATIONS} ]
        	        		do
	                       			curl ${CURL_OPTIONS} "${CURL_PROBE_URL}" >>/tmp/govway_check_${NUM_CONCURRENT_INVOCATION}.log 2>&1 &
						INVOCATIONS_PIDS="${INVOCATIONS_PIDS} $!"
						NUM_CONCURRENT_INVOCATION=$(( ${NUM_CONCURRENT_INVOCATION} + 1 ))
					done
					wait ${INVOCATIONS_PIDS}
					NUM_PROBE_INVOCATION=$(( ${NUM_PROBE_INVOCATION} + 1 ))
				done
			fi
			echo " Ok."
		fi

		touch /tmp/govway_ready
		echo "INFO: GovWay avviato "
	fi
fi
[ "${USERID}" == '1234' ] &&  chmod -R 777 ${GOVWAY_HOME}


wait ${TOMCAT_PID}
exec 6>&-
