#!/bin/bash -x
CLI_SCRIPT_FILE="$1"  
CLI_SCRIPT_CUSTOM_DIR="${JBOSS_HOME}/standalone/configuration/custom_cli"


case "${GOVWAY_DB_TYPE:-hsql}" in
postgresql)

    GOVWAY_DS_DRIVER_CLASS='org.postgresql.Driver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'

    # Le variabili DATASOURCE_CONN_PARAM, DATASOURCE_{CONF,TRAC,STAT}_CONN_PARAM, sono impostate dallo standalone_wrapper.sh
    JDBC_RUN_URL='jdbc:postgresql://\${env.GOVWAY_DB_SERVER}/\${env.GOVWAY_DB_NAME}\${env.DATASOURCE_CONN_PARAM:}'
    JDBC_RUN_AUTH="/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=user-name, value=\${env.GOVWAY_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=password, value=\${env.GOVWAY_DB_PASSWORD})"

    JDBC_CONF_URL='jdbc:postgresql://\${env.GOVWAY_CONF_DB_SERVER}/\${env.GOVWAY_CONF_DB_NAME}\${env.DATASOURCE_CONF_CONN_PARAM:}'
    JDBC_CONF_AUTH="/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=user-name, value=\${env.GOVWAY_CONF_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=password, value=\${env.GOVWAY_CONF_DB_PASSWORD})"

    JDBC_TRAC_URL='jdbc:postgresql://\${env.GOVWAY_TRAC_DB_SERVER}/\${env.GOVWAY_TRAC_DB_NAME}\${env.DATASOURCE_TRAC_CONN_PARAM:}'
    JDBC_TRAC_AUTH="/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=user-name, value=\${env.GOVWAY_TRAC_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=password, value=\${env.GOVWAY_TRAC_DB_PASSWORD})"

    JDBC_STAT_URL='jdbc:postgresql://\${env.GOVWAY_STAT_DB_SERVER}/\${env.GOVWAY_STAT_DB_NAME}\${env.DATASOURCE_STAT_CONN_PARAM:}'
    JDBC_STAT_AUTH="/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=user-name, value=\${env.GOVWAY_STAT_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=password, value=\${env.GOVWAY_STAT_DB_PASSWORD})"

;;

mysql)

    GOVWAY_DS_DRIVER_CLASS='com.mysql.cj.jdbc.Driver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'

    # Le variabili DATASOURCE_CONN_PARAM, DATASOURCE_{CONF,TRAC,STAT}_CONN_PARAM, sono impostate dallo standalone_wrapper.sh
    JDBC_RUN_URL='jdbc:mysql://\${env.GOVWAY_DB_SERVER}/\${env.GOVWAY_DB_NAME}\${env.DATASOURCE_CONN_PARAM:}'
    JDBC_RUN_AUTH="/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=user-name, value=\${env.GOVWAY_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=password, value=\${env.GOVWAY_DB_PASSWORD})"

    JDBC_CONF_URL='jdbc:mysql://\${env.GOVWAY_CONF_DB_SERVER}/\${env.GOVWAY_CONF_DB_NAME}\${env.DATASOURCE_CONF_CONN_PARAM:}'
    JDBC_CONF_AUTH="/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=user-name, value=\${env.GOVWAY_CONF_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=password, value=\${env.GOVWAY_CONF_DB_PASSWORD})"

    JDBC_TRAC_URL='jdbc:mysql://\${env.GOVWAY_TRAC_DB_SERVER}/\${env.GOVWAY_TRAC_DB_NAME}\${env.DATASOURCE_TRAC_CONN_PARAM:}'
    JDBC_TRAC_AUTH="/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=user-name, value=\${env.GOVWAY_TRAC_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=password, value=\${env.GOVWAY_TRAC_DB_PASSWORD})"

    JDBC_STAT_URL='jdbc:mysql://\${env.GOVWAY_STAT_DB_SERVER}/\${env.GOVWAY_STAT_DB_NAME}\${env.DATASOURCE_STAT_CONN_PARAM:}'
    JDBC_STAT_AUTH="/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=user-name, value=\${env.GOVWAY_STAT_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=password, value=\${env.GOVWAY_STAT_DB_PASSWORD})"

;;
mariadb)

    GOVWAY_DS_DRIVER_CLASS='org.mariadb.jdbc.Driver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'


    # Le variabili DATASOURCE_CONN_PARAM, DATASOURCE_{CONF,TRAC,STAT}_CONN_PARAM, sono impostate dallo standalone_wrapper.sh
    JDBC_RUN_URL='jdbc:mariadb://\${env.GOVWAY_DB_SERVER}/\${env.GOVWAY_DB_NAME}\${env.DATASOURCE_CONN_PARAM:}'
    JDBC_RUN_AUTH="/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=user-name, value=\${env.GOVWAY_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=password, value=\${env.GOVWAY_DB_PASSWORD})"

    JDBC_CONF_URL='jdbc:mariadb://\${env.GOVWAY_CONF_DB_SERVER}/\${env.GOVWAY_CONF_DB_NAME}\${env.DATASOURCE_CONF_CONN_PARAM:}'
    JDBC_CONF_AUTH="/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=user-name, value=\${env.GOVWAY_CONF_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=password, value=\${env.GOVWAY_CONF_DB_PASSWORD})"

    JDBC_TRAC_URL='jdbc:mariadb://\${env.GOVWAY_TRAC_DB_SERVER}/\${env.GOVWAY_TRAC_DB_NAME}\${env.DATASOURCE_TRAC_CONN_PARAM:}'
    JDBC_TRAC_AUTH="/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=user-name, value=\${env.GOVWAY_TRAC_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=password, value=\${env.GOVWAY_TRAC_DB_PASSWORD})"

    JDBC_STAT_URL='jdbc:mariadb://\${env.GOVWAY_STAT_DB_SERVER}/\${env.GOVWAY_STAT_DB_NAME}\${env.DATASOURCE_STAT_CONN_PARAM:}'
    JDBC_STAT_AUTH="/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=user-name, value=\${env.GOVWAY_STAT_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=password, value=\${env.GOVWAY_STAT_DB_PASSWORD})"


;;
oracle)

    GOVWAY_DS_DRIVER_CLASS='oracle.jdbc.OracleDriver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1 FROM DUAL'

    # Le variabili ORACLE_JDBC_SERVER_PREFIX ed ORACLE_JDBC_DB_SEPARATOR sono impostate dallo standalone_wrapper.sh
    # Le variabili DATASOURCE_CONN_PARAM, DATASOURCE_{CONF,TRAC,STAT}_CONN_PARAM, sono impostate dallo standalone_wrapper.sh
    JDBC_RUN_URL='jdbc:oracle:thin:@\${env.ORACLE_JDBC_SERVER_PREFIX}\${env.GOVWAY_DB_SERVER}\${env.ORACLE_JDBC_DB_SEPARATOR}\${env.GOVWAY_DB_NAME}\${env.DATASOURCE_CONN_PARAM:}'
    JDBC_RUN_AUTH="/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=user-name, value=\${env.GOVWAY_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=password, value=\${env.GOVWAY_DB_PASSWORD})"

    JDBC_CONF_URL='jdbc:oracle:thin:@\${env.ORACLE_JDBC_SERVER_PREFIX}\${env.GOVWAY_CONF_DB_SERVER}\${env.ORACLE_JDBC_DB_SEPARATOR}\${env.GOVWAY_CONF_DB_NAME}\${env.DATASOURCE_CONF_CONN_PARAM:}' 
    JDBC_CONF_AUTH="/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=user-name, value=\${env.GOVWAY_CONF_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=password, value=\${env.GOVWAY_CONF_DB_PASSWORD})"

    JDBC_TRAC_URL='jdbc:oracle:thin:@\${env.ORACLE_JDBC_SERVER_PREFIX}\${env.GOVWAY_TRAC_DB_SERVER}\${env.ORACLE_JDBC_DB_SEPARATOR}\${env.GOVWAY_TRAC_DB_NAME}\${env.DATASOURCE_TRAC_CONN_PARAM:}' 
    JDBC_TRAC_AUTH="/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=user-name, value=\${env.GOVWAY_TRAC_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=password, value=\${env.GOVWAY_TRAC_DB_PASSWORD})"

    JDBC_STAT_URL='jdbc:oracle:thin:@\${env.ORACLE_JDBC_SERVER_PREFIX}\${env.GOVWAY_STAT_DB_SERVER}\${env.ORACLE_JDBC_DB_SEPARATOR}\${env.GOVWAY_STAT_DB_NAME}\${env.DATASOURCE_STAT_CONN_PARAM:}'
    JDBC_STAT_AUTH="/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=user-name, value=\${env.GOVWAY_STAT_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=password, value=\${env.GOVWAY_STAT_DB_PASSWORD})"

;;
hsql|*)
    GOVWAY_DS_DRIVER_CLASS='org.hsqldb.jdbc.JDBCDriver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT * FROM (VALUES(1));'

    JDBC_RUN_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"
    JDBC_RUN_AUTH="/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=user-name, value=govway)
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=password, value=govway)"

    JDBC_CONF_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"
    JDBC_CONF_AUTH="/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=user-name, value=govway)
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=password, value=govway)"

    JDBC_TRAC_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"
    JDBC_TRAC_AUTH="/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=user-name, value=govway)
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=password, value=govway)"

    JDBC_STAT_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/govway;shutdown=true"
    JDBC_STAT_AUTH="/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=user-name, value=govway)
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=password, value=govway)"
;;
esac

cat - << EOCLI >> "${CLI_SCRIPT_FILE}"
embed-server --server-config=standalone.xml --std-out=echo
echo "Carico modulo e driver JDBC per ${GOVWAY_DB_TYPE:-hsql}"
module add --name=${GOVWAY_DB_TYPE:-hsql}Mod --resources=/tmp/placeholder-driver-jdbc.jar --dependencies=javax.api,javax.transaction.api --allow-nonexistent-resources
/subsystem=datasources/jdbc-driver=${GOVWAY_DB_TYPE:-hsql}Driver:add(driver-name=${GOVWAY_DB_TYPE:-hsql}Driver, driver-module-name=${GOVWAY_DB_TYPE:-hsql}Mod, driver-class-name=${GOVWAY_DS_DRIVER_CLASS})
stop-embedded-server
embed-server --server-config=standalone.xml --std-out=echo
echo "Preparo datasource org.govway.datasource"
/subsystem=datasources/data-source=org.govway.datasource: add(jndi-name=java:/org.govway.datasource,enabled=true,use-java-context=true,use-ccm=true, connection-url="${JDBC_RUN_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
${JDBC_RUN_AUTH}
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=driver-class, value="${GOVWAY_DS_DRIVER_CLASS}")
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=check-valid-connection-sql, value="${GOVWAY_DS_VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=new-connection-sql, value="${GOVWAY_DS_VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=validate-on-match, value=true)
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=idle-timeout-minutes,value=\${env.GOVWAY_DS_IDLE_TIMEOUT:5})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=blocking-timeout-wait-millis,value=\${env.GOVWAY_DS_BLOCKING_TIMEOUT:30000})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=pool-prefill, value=true)
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=prepared-statements-cache-size, value=\${env.GOVWAY_DS_PSCACHESIZE:20})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=pool-use-strict-min, value=false)
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=initial-pool-size, value=\${env.GOVWAY_INITIALSIZE_POOL:2})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=min-pool-size, value=\${env.GOVWAY_MIN_POOL:2})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=max-pool-size, value=\${env.GOVWAY_MAX_POOL:50})
echo "Preparo datasource org.govway.datasource.console"
/subsystem=datasources/data-source=org.govway.datasource.console: add(jndi-name=java:/org.govway.datasource.console,enabled=true,use-java-context=true,use-ccm=true, statistics-enabled=true, connection-url="${JDBC_CONF_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
${JDBC_CONF_AUTH}
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=driver-class, value="${GOVWAY_DS_DRIVER_CLASS}")
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=check-valid-connection-sql, value="${GOVWAY_DS_VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=new-connection-sql, value="${GOVWAY_DS_VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=validate-on-match, value=true)
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=idle-timeout-minutes,value=\${env.GOVWAY_CONF_DS_IDLE_TIMEOUT:5})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=blocking-timeout-wait-millis,value=\${env.GOVWAY_CONF_DS_BLOCKING_TIMEOUT:30000})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=pool-prefill, value=true)
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=prepared-statements-cache-size, value=\${env.GOVWAY_CONF_DS_PSCACHESIZE:20})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=pool-use-strict-min, value=false)
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=initial-pool-size, value=\${env.GOVWAY_CONF_INITIALSIZE_POOL:2})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=min-pool-size, value=\${env.GOVWAY_CONF_MIN_POOL:2})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=max-pool-size, value=\${env.GOVWAY_CONF_MAX_POOL:10})
echo "Preparo datasource org.govway.datasource.tracciamento"
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: add(jndi-name=java:/org.govway.datasource.tracciamento,enabled=true,use-java-context=true,use-ccm=true, statistics-enabled=true, connection-url="${JDBC_TRAC_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
${JDBC_TRAC_AUTH}
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=driver-class, value="${GOVWAY_DS_DRIVER_CLASS}")
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=check-valid-connection-sql, value="${GOVWAY_DS_VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=new-connection-sql, value="${GOVWAY_DS_VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=validate-on-match, value=true)
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=idle-timeout-minutes,value=\${env.GOVWAY_TRAC_DS_IDLE_TIMEOUT:5})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=blocking-timeout-wait-millis,value=\${env.GOVWAY_TRAC_DS_BLOCKING_TIMEOUT:30000})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=pool-prefill, value=true)
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=prepared-statements-cache-size, value=\${env.GOVWAY_TRAC_DS_PSCACHESIZE:20})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=pool-use-strict-min, value=false)
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=initial-pool-size, value=\${env.GOVWAY_TRAC_INITIALSIZE_POOL:2})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=min-pool-size, value=\${env.GOVWAY_TRAC_MIN_POOL:2})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=max-pool-size, value=\${env.GOVWAY_TRAC_MAX_POOL:50})
echo "Preparo datasource org.govway.datasource.statistiche"
/subsystem=datasources/data-source=org.govway.datasource.statistiche: add(jndi-name=java:/org.govway.datasource.statistiche,enabled=true,use-java-context=true,use-ccm=true, statistics-enabled=true, connection-url="${JDBC_STAT_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
${JDBC_STAT_AUTH}
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=driver-class, value="${GOVWAY_DS_DRIVER_CLASS}")
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=check-valid-connection-sql, value="${GOVWAY_DS_VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=new-connection-sql, value="${GOVWAY_DS_VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=validate-on-match, value=true)
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=idle-timeout-minutes,value=\${env.GOVWAY_STAT_DS_IDLE_TIMEOUT:5})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=blocking-timeout-wait-millis,value=\${env.GOVWAY_STAT_DS_BLOCKING_TIMEOUT:30000})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=pool-prefill, value=true)
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=prepared-statements-cache-size, value=\${env.GOVWAY_STAT_DS_PSCACHESIZE:20})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=pool-use-strict-min, value=false)
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=initial-pool-size, value=\${env.GOVWAY_STAT_INITIALSIZE_POOL:1})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=min-pool-size, value=\${env.GOVWAY_STAT_MIN_POOL:1})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=max-pool-size, value=\${env.GOVWAY_STAT_MAX_POOL:5})
EOCLI


if [ -d "${CLI_SCRIPT_CUSTOM_DIR}" -a -n "$(ls -A ${CLI_SCRIPT_CUSTOM_DIR} 2>/dev/null)" ]
then
    cli=""
	for cli in ${CLI_SCRIPT_CUSTOM_DIR}/*
    do
		echo >> "${CLI_SCRIPT_FILE}"
        cat ${cli} >> "${CLI_SCRIPT_FILE}"
	done
fi

