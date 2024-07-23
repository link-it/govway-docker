#!/bin/bash -x
CLI_SCRIPT_FILE="$1"  
CLI_SCRIPT_CUSTOM_DIR="${CATALINA_HOME}/conf/custom_cli"


case "${GOVWAY_DB_TYPE:-hsql}" in
postgresql)
    
    GOVWAY_DS_DRIVER_CLASS='org.postgresql.Driver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'

    # Le variabili DATASOURCE_CONN_PARAM, DATASOURCE_{CONF,TRAC,STAT}_CONN_PARAM, sono impostate dallo standalone_wrapper.sh
    JDBC_RUN_URL='jdbc:postgresql://${GOVWAY_DB_SERVER}/${GOVWAY_DB_NAME}${DATASOURCE_CONN_PARAM}' 

    JDBC_CONF_URL='jdbc:postgresql://${GOVWAY_CONF_DB_SERVER}/${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}'

    JDBC_TRAC_URL='jdbc:postgresql://${GOVWAY_TRAC_DB_SERVER}/${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}'

    JDBC_STAT_URL='jdbc:postgresql://${GOVWAY_STAT_DB_SERVER}/${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}'

;;

mysql)
    
    GOVWAY_DS_DRIVER_CLASS='com.mysql.cj.jdbc.Driver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'

    # Le variabili DATASOURCE_CONN_PARAM, DATASOURCE_{CONF,TRAC,STAT}_CONN_PARAM, sono impostate dallo standalone_wrapper.sh
    JDBC_RUN_URL='jdbc:mysql://${GOVWAY_DB_SERVER}/${GOVWAY_DB_NAME}${DATASOURCE_CONN_PARAM}'

    JDBC_CONF_URL='jdbc:mysql://${GOVWAY_CONF_DB_SERVER}/${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}'

    JDBC_TRAC_URL='jdbc:mysql://${GOVWAY_TRAC_DB_SERVER}/${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}'

    JDBC_STAT_URL='jdbc:mysql://${GOVWAY_STAT_DB_SERVER}/${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}'

;;
mariadb)
    
    GOVWAY_DS_DRIVER_CLASS='org.mariadb.jdbc.Driver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1;'


    # Le variabili DATASOURCE_CONN_PARAM, DATASOURCE_{CONF,TRAC,STAT}_CONN_PARAM, sono impostate dallo standalone_wrapper.sh
    JDBC_RUN_URL='jdbc:mariadb://${GOVWAY_DB_SERVER}/${GOVWAY_DB_NAME}${DATASOURCE_CONN_PARAM}'

    JDBC_CONF_URL='jdbc:mariadb://${GOVWAY_CONF_DB_SERVER}/${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}'

    JDBC_TRAC_URL='jdbc:mariadb://${GOVWAY_TRAC_DB_SERVER}/${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}'

    JDBC_STAT_URL='jdbc:mariadb://${GOVWAY_STAT_DB_SERVER}/${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}'

;;
oracle)
    
    GOVWAY_DS_DRIVER_CLASS='oracle.jdbc.OracleDriver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT 1 FROM DUAL'

    # Le variabili ORACLE_JDBC_SERVER_PREFIX ed ORACLE_JDBC_DB_SEPARATOR sono impostate dallo standalone_wrapper.sh
    # Le variabili DATASOURCE_CONN_PARAM, DATASOURCE_{CONF,TRAC,STAT}_CONN_PARAM, sono impostate dallo standalone_wrapper.sh
    JDBC_RUN_URL='jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_DB_NAME}${DATASOURCE_CONN_PARAM}'

    JDBC_CONF_URL='jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_CONF_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_CONF_DB_NAME}${DATASOURCE_CONF_CONN_PARAM}' 

    JDBC_TRAC_URL='jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_TRAC_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_TRAC_DB_NAME}${DATASOURCE_TRAC_CONN_PARAM}' 

    JDBC_STAT_URL='jdbc:oracle:thin:@${ORACLE_JDBC_SERVER_PREFIX}${GOVWAY_STAT_DB_SERVER}${ORACLE_JDBC_DB_SEPARATOR}${GOVWAY_STAT_DB_NAME}${DATASOURCE_STAT_CONN_PARAM}'

;;
hsql|*)
    GOVWAY_DS_DRIVER_CLASS='org.hsqldb.jdbc.JDBCDriver'
    GOVWAY_DS_VALID_CONNECTION_SQL='SELECT * FROM (VALUES(1));'

    JDBC_RUN_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/\${GOVWAY_DB_NAME};shutdown=true"

    JDBC_CONF_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/\${GOVWAY_CONF_DB_NAME};shutdown=true"

    JDBC_TRAC_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/\${GOVWAY_TRAC_DB_NAME};shutdown=true"

    JDBC_STAT_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/\${GOVWAY_STAT_DB_NAME};shutdown=true"
;;
esac




cat - << EOCLI >> "${CLI_SCRIPT_FILE}"
# Aggiungi Resource org.govway.datasource
/Server/GlobalNamingResources/Resource:add name=org.govway.datasource, auth=Container, type=javax.sql.DataSource, driverClassName=\${GOVWAY_DS_DRIVER_CLASS}, url=${JDBC_RUN_URL}, username=\${GOVWAY_DB_USER}, password=\${GOVWAY_DB_PASSWORD}, initialSize=\${GOVWAY_MIN_POOL:-2}, maxTotal=\${GOVWAY_MAX_POOL:-50}, minIdle=0, maxIdle=\${GOVWAY_MIN_POOL:-2}, maxWaitMillis=\${GOVWAY_DS_BLOCKING_TIMEOUT:-30000}, defaultTransactionIsolation=READ_COMMITTED, validationQuery=\${GOVWAY_DS_VALID_CONNECTION_SQL}, validationQueryTimeout=0, testOnBorrow=true, testOnReturn=false, testWhileIdle=true, minEvictableIdleTimeMillis=300000, numTestsPerEvictionRun=10, timeBetweenEvictionRunsMillis=60000, poolPreparedStatements=true, maxOpenPreparedStatements=\${GOVWAY_DS_PSCACHESIZE:-100}
# Aggiungi ResourceLink org.govway.datasource
/Context/ResourceLink:add name=org.govway.datasource, global=org.govway.datasource, type=javax.sql.DataSource
# Aggiungi Resource org.govway.datasource.console
/Server/GlobalNamingResources/Resource:add name=org.govway.datasource.console, auth=Container, type=javax.sql.DataSource, driverClassName=\${GOVWAY_DS_DRIVER_CLASS}, url=${JDBC_CONF_URL}, username=\${GOVWAY_CONF_DB_USER}, password=\${GOVWAY_CONF_DB_PASSWORD}, initialSize=\${GOVWAY_CONF_MIN_POOL:-2}, maxTotal=\${GOVWAY_CONF_MAX_POOL:-50}, minIdle=0, maxIdle=\${GOVWAY_CONF_MIN_POOL:-2}, maxWaitMillis=\${GOVWAY_CONF_DS_BLOCKING_TIMEOUT:-30000}, defaultTransactionIsolation=READ_COMMITTED, validationQuery=\${GOVWAY_DS_VALID_CONNECTION_SQL}, validationQueryTimeout=0, testOnBorrow=true, testOnReturn=false, testWhileIdle=true, minEvictableIdleTimeMillis=300000, numTestsPerEvictionRun=10, timeBetweenEvictionRunsMillis=60000, poolPreparedStatements=true, maxOpenPreparedStatements=\${GOVWAY_CONF_DS_PSCACHESIZE:-100}
# Aggiungi ResourceLink org.govway.datasource.console
/Context/ResourceLink:add name=org.govway.datasource.console, global=org.govway.datasource.console, type=javax.sql.DataSource
# Aggiungi Resource org.govway.datasource.tracciamento
/Server/GlobalNamingResources/Resource:add name=org.govway.datasource.tracciamento, auth=Container, type=javax.sql.DataSource, driverClassName=\${GOVWAY_DS_DRIVER_CLASS}, url=${JDBC_TRAC_URL}, username=\${GOVWAY_TRAC_DB_USER}, password=\${GOVWAY_TRAC_DB_PASSWORD}, initialSize=\${GOVWAY_TRAC_MIN_POOL:-2}, maxTotal=\${GOVWAY_TRAC_MAX_POOL:-50}, minIdle=0, maxIdle=\${GOVWAY_TRAC_MIN_POOL:-2}, maxWaitMillis=\${GOVWAY_TRAC_DS_BLOCKING_TIMEOUT:-30000}, defaultTransactionIsolation=READ_COMMITTED, validationQuery=\${GOVWAY_DS_VALID_CONNECTION_SQL}, validationQueryTimeout=0, testOnBorrow=true, testOnReturn=false, testWhileIdle=true, minEvictableIdleTimeMillis=300000, numTestsPerEvictionRun=10, timeBetweenEvictionRunsMillis=60000, poolPreparedStatements=true, maxOpenPreparedStatements=\${GOVWAY_TRAC_DS_PSCACHESIZE:-100}
# Aggiungi ResourceLink org.govway.datasource.tracciamento
/Context/ResourceLink:add name=org.govway.datasource.tracciamento, global=org.govway.datasource.tracciamento, type=javax.sql.DataSource
# Aggiungi Resource org.govway.datasource.statistiche
/Server/GlobalNamingResources/Resource:add name=org.govway.datasource.statistiche, auth=Container, type=javax.sql.DataSource, driverClassName=\${GOVWAY_DS_DRIVER_CLASS}, url=${JDBC_STAT_URL}, username=\${GOVWAY_STAT_DB_USER}, password=\${GOVWAY_STAT_DB_PASSWORD}, initialSize=\${GOVWAY_STAT_MIN_POOL:-2}, maxTotal=\${GOVWAY_STAT_MAX_POOL:-50}, minIdle=0, maxIdle=\${GOVWAY_STAT_MIN_POOL:-2}, maxWaitMillis=\${GOVWAY_STAT_DS_BLOCKING_TIMEOUT:-30000}, defaultTransactionIsolation=READ_COMMITTED, validationQuery=\${GOVWAY_DS_VALID_CONNECTION_SQL}, validationQueryTimeout=0, testOnBorrow=true, testOnReturn=false, testWhileIdle=true, minEvictableIdleTimeMillis=300000, numTestsPerEvictionRun=10, timeBetweenEvictionRunsMillis=60000, poolPreparedStatements=true, maxOpenPreparedStatements=\${GOVWAY_STAT_DS_PSCACHESIZE:-100}
# Aggiungi ResourceLink org.govway.datasource.statistiche
/Context/ResourceLink:add name=org.govway.datasource.statistiche, global=org.govway.datasource.statistiche, type=javax.sql.DataSource
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

