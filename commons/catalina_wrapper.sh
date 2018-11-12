#!/bin/bash

cat - >> ${CATALINA_HOME}/conf/catalina.properties <<EOPROPERTIES
$(env |grep -E 'GOVWAY')
user.language=it
user.country=IT
javax.net.debug=${JAVA_SSL_DEBUG}
EOPROPERTIES

echo "CATALINA_OPTS=\"-XX:+UseConcMarkSweepGC\"" > ${CATALINA_HOME}/bin/setenv.sh



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
	echo "Waiting Database server startup ..."
	sleep ${DB_CHECK_FIRST_SLEEP_TIME}s
	DB_READY=1
	NUM_RETRY=0
	while [ ${DB_READY} -ne 0 -a ${NUM_RETRY} -le ${DB_CHECK_MAX_RETRY} ]
	do
		nc  -w "$DB_CHECK_CONNECT_TIMEOUT" -z "$GOVWAY_DATABASE_SERVER" "$GOVWAY_DATABASE_PORT"
	        DB_READY=$?
        	NUM_RETRY=$(( ${NUM_RETRY} + 1 ))
		if [  ${DB_READY} -ne 1 ]
		then
	        	echo "Waiting Database server startup ..."
		        sleep ${DB_CHECK_SLEEP_TIME}s
		fi
	done
	if [  ${DB_READY} -ne 0 -a ${NUM_RETRY} -eq ${DB_CHECK_MAX_RETRY} ]
	then
		echo "FATAL: Database Server check failed after $((${DB_CHECK_SLEEP_TIME=} * ${DB_CHECK_MAX_RETRY})) seconds  ... Exiting."
		exit 1
	fi
fi

coproc TOMCAT { catalina.sh $@; }





## Main
if [ "${SKIP_STARTUP_CHECK}" != "TRUE" ]
then

	/bin/rm -f  /tmp/govway_ready
	echo "INFO: Waiting GovWay applications startup ..."
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
			echo "INFO: Waiting GovWay applications startup ..."
			sleep ${STARTUP_CHECK_SLEEP_TIME}s
		fi
	done

	if [ ${NUM_RETRY} -eq ${STARTUP_CHECK_MAX_RETRY} ]
	then
		echo "WARNING: GovWay NOT ready after $((${DB_CHECK_SLEEP_TIME=} * ${DB_CHECK_MAX_RETRY})) seconds ."
	else
		if [ "${SKIP_WARMUP}" != "TRUE" ]
		then
			PROBE_INVOCATIONS_TOTAL=3
			CONCURRENT_INVOCATION=FALSE
			CONCURRENT_PROBE_INVOCATIONS=10
			CURL_OPTIONS="--noproxy 127.0.0.1 -s -w %{http_code} --connect-timeout "${WARMUP_CONNECT_TIMEOUT}" --max-time 5"
			CURL_PROBE_URL="http://127.0.0.1:8080/govway/check"
		
			echo -n "INFO: Warming up GovWay ..."
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
			echo " complete."
		fi

		touch /tmp/govway_ready
		echo "INFO: GovWay Ready"
	fi
fi

wait ${TOMCAT_PID}

