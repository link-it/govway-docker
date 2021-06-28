#!/bin/bash
exec 6<> /tmp/catalina_wrapper_debug.log
exec 2>&6
set -x


## Const
STARTUP_CHECK_FIRST_SLEEP_TIME=20
STARTUP_CHECK_SLEEP_TIME=5
STARTUP_CHECK_MAX_RETRY=60
STARTUP_CHECK_REGEX='GovWay/?.* \(www.govway.org\) avviata correttamente in .* secondi'

DB_CHECK_FIRST_SLEEP_TIME=10
DB_CHECK_SLEEP_TIME=5
DB_CHECK_MAX_RETRY=60
DB_CHECK_CONNECT_TIMEOUT=2


## Var
SKIP_STARTUP_CHECK=${SKIP_STARTUP_CHECK:=FALSE}
SKIP_DB_CHECK=${SKIP_DB_CHECK:=TRUE}
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

	################################################
	## Preparazione database (Hsql se installato) ##
	################################################
	if [ -z "${GOVWAY_DATABASE_SERVER}" ]
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
	else

		echo "INFO: Preparazione accesso base dati PGSQL ..."
		cat - <<EOSQLTOOL > /root/sqltool.rc
urlid govwayDB
url jdbc:postgresql://${GOVWAY_DATABASE_SERVER}:${GOVWAY_DATABASE_PORT}/${GOVWAY_DATABASE_NAME}
username ${GOVWAY_DATABASE_USERNAME}
password ${GOVWAY_DATABASE_USERPASSWD}
driver org.postgresql.Driver
transiso TRANSACTION_READ_COMMITTED
charset UTF-8
EOSQLTOOL
	fi

	###################################################
	## Preparazione certificati per connettore https ##
	###################################################
	export PKI_DIR=${GOVWAY_HOME}/pki
        FQDN="${FQDN:=test.govway.org}"
	# evito di rigenerare i certificati se gia esistenti
	#if [ ! -f "${PKI_DIR}"/stores/keystore_server.jks ]
        if [ "$(echo ${PKI_DIR}/CA_*)" == "${PKI_DIR}"'/CA_*' ] 
        then
		echo -n "INFO: Generazione certificati SSL ..."
                bash -x ${CATALINA_HOME}/bin/genera_certs.sh 2> /tmp/debug_certificate.log
		echo " Ok."
        fi

	###########################
	## configurazione tomcat ##
	##########################
	echo "CATALINA_OPTS=\"-XX:+UseConcMarkSweepGC -Duser.language=it -Duser.country=IT -Dfile.encoding=UTF-8\"" > ${CATALINA_HOME}/bin/setenv.sh
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
		# evito di sovrascrivere i files di properties gia esistenti
	if [ "$(echo ${GOVWAY_HOME}/etc/*.properties)" == "${GOVWAY_HOME}"'/etc/*.properties' ]
	then
		cp /opt/govway-installer-${GOVWAY_FULLVERSION}/dist/cfg/*.properties ${GOVWAY_HOME}/etc
	fi
	rm -rf ${CATALINA_HOME}/webapps/*
	cp /opt/govway-installer-${GOVWAY_FULLVERSION}/dist/archivi/*.war ${CATALINA_HOME}/webapps

	if [ "${GOVWAY_INTERFACE,,}" == "web" ] 
	then
		rm -f ${CATALINA_HOME}/webapps/govwayAPIMonitor.war ${CATALINA_HOME}/webapps/govwayAPIConfig.war
	elif [ "${GOVWAY_INTERFACE,,}" == "rest" ]
	then
		rm -f ${CATALINA_HOME}/webapps/govwayMonitor.war ${CATALINA_HOME}/webapps/govwayConsole.war
#	elif [ ${GOVWAY_INTERFACE,,} == "full" -o -z "${GOVWAY_INTERFACE,,}" ]
#	then
#		: # In qualsiasi altro caso fare un deploy completo
	fi
#	[ ${GOVWAY_REST,,} == "false" -o ${GOVWAY_REST,,} == "no" -o ${GOVWAY_REST,,} == "0" ] && rm -f ${CATALINA_HOME}/webapps/govwayAPIMonitor.war ${CATALINA_HOME}/webapps/govwayAPIConfig.war


fi

## Avvio server ssh
if [ -n "${SSH_PUBLIC_KEY}" ]
then
	echo "${SSH_PUBLIC_KEY}" > /tmp/pubkey
	if ! ssh-keygen -l -f /tmp/pubkey >/dev/null 2>&1
	then

                for formato in RFC4716 PKCS8 PEM
                do
                        ssh-keygen -i -m ${formato} -f /tmp/pubkey > /tmp/openssh_pubkey 2>/dev/null
                        [ $? -eq 0 ] && break
                done
	else
		mv -f /tmp/pubkey /tmp/openssh_pubkey
	fi

	if ssh-keygen -l -f /tmp/openssh_pubkey >/dev/null 2>&1
	then
		echo "INFO: Inizio configurazione server SSH ..."
		sshd-keygen >/dev/null 2>&1
		cat - << EOSSHD > /etc/ssh/sshd_config
X11Forwarding no
IgnoreRhosts yes
PermitEmptyPasswords no
MaxAuthTries 3
PubkeyAuthentication yes
PasswordAuthentication no
EOSSHD
		mkdir ~/.ssh
		cp /tmp/openssh_pubkey ~/.ssh/authorized_keys
		chmod 600 ~/.ssh/authorized_keys
		coproc SSHD { /usr/sbin/sshd -D; }
		echo "INFO: Configurazione server SSH completata"
		echo "WARN: Accesso al server consentito esclusivamente alla chiave '$(ssh-keygen -l -f /tmp/openssh_pubkey)'"
	else
		
		echo "ERROR: La chiave pubblica non e' valida"
		echo "INFO: Impossibile procedere con la configurazione del server SSH"
	fi

	rm -f /tmp/pubkey  /tmp/openssh_pubkey
fi


if [ "${SKIP_DB_CHECK}" != "TRUE" ]
then
	echo "INFO: Attendo avvio della base dati ..."
	sleep ${DB_CHECK_FIRST_SLEEP_TIME}s
	DB_READY=1
	NUM_RETRY=0
	while [ ${DB_READY} -ne 0 -a ${NUM_RETRY} -lt ${DB_CHECK_MAX_RETRY} ]
	do
		#POSTGRES_JDBC_VERSION non e' valorizzata quando il container e' in modalita standalone
		EXIST="$(java -Dfile.encoding=UTF-8 -cp ${CATALINA_HOME}/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/sqltool.jar org.hsqldb.cmdline.SqlTool \
			--continueOnErr=false \
			--sql='SELECT count(*) from db_info;' \
			govwayDB 2> /dev/null |tr -d ' ')"
		[[ $EXIST  > 0 ]]
		DB_READY=$?
		NUM_RETRY=$(( ${NUM_RETRY} + 1 ))
		if [  ${DB_READY} -ne 0 ]
		then
			echo "INFO: Attendo disponibilita' della base dati .."
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
exec  /usr/local/bin/gosu tomcat catalina.sh "$@" &
TOMCAT_PID="$!"

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
		if [  ${GOVWAY_READY} -ne 0 ]
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
		touch /tmp/govway_ready
		echo "INFO: GovWay avviato "
	fi
fi
[ "${USERID}" == '1234' ] &&  chmod -R 777 ${GOVWAY_HOME}


wait ${TOMCAT_PID}
exec 6>&-
