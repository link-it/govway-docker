#!/bin/bash     
CLI_SCRIPT_FILE="$1"  
    
case "${GOVWAY_DB_TYPE:-hsql}" in
postgresql)
    DRIVER_JDBC="/opt/postgresql-${POSTGRES_JDBC_VERSION}.jar"
    DRIVER_JDBC_CLASS='org.postgresql.Driver'
    VALID_CONNECTION_SQL='SELECT 1;'

    JDBC_RUN_URL='jdbc:postgresql://\${env.GOVWAY_DB_SERVER}/\${env.GOVWAY_DB_NAME}?\${env.GOVWAY_DS_CONN_PARAM:}'
    JDBC_RUN_AUTH="/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=user-name, value=\${env.GOVWAY_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=password, value=\${env.GOVWAY_DB_PASSWORD})"

    JDBC_CONF_URL='jdbc:postgresql://\${env.GOVWAY_CONF_DB_SERVER}/\${env.GOVWAY_CONF_DB_NAME}?\${env.GOVWAY_CONF_DS_CONN_PARAM:}'
    JDBC_CONF_AUTH="/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=user-name, value=\${env.GOVWAY_CONF_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=password, value=\${env.GOVWAY_CONF_DB_PASSWORD})"

    JDBC_TRAC_URL='jdbc:postgresql://\${env.GOVWAY_TRAC_DB_SERVER}/\${env.GOVWAY_TRAC_DB_NAME}?\${env.GOVWAY_TRAC_DS_CONN_PARAM:}'
    JDBC_TRAC_AUTH="/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=user-name, value=\${env.GOVWAY_TRAC_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=password, value=\${env.GOVWAY_TRAC_DB_PASSWORD})"

    JDBC_STAT_URL='jdbc:postgresql://\${env.GOVWAY_STAT_DB_SERVER}/\${env.GOVWAY_STAT_DB_NAME}?\${env.GOVWAY_STAT_DS_CONN_PARAM:}'
    JDBC_STAT_AUTH="/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=user-name, value=\${env.GOVWAY_STAT_DB_USER})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=password, value=\${env.GOVWAY_STAT_DB_PASSWORD})"

;;
hsql|*)
    DRIVER_JDBC="opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/hsqldb.jar"
    DRIVER_JDBC_CLASS='org.hsqldb.jdbc.JDBCDriver'
    VALID_CONNECTION_SQL='SELECT 1'

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
module add --name=${GOVWAY_DB_TYPE:-hsql}Mod --resources=${DRIVER_JDBC} --dependencies=javax.api,javax.transaction.api
/subsystem=datasources/jdbc-driver=${GOVWAY_DB_TYPE:-hsql}Driver:add(driver-name=${GOVWAY_DB_TYPE:-hsql}Driver, driver-module-name=${GOVWAY_DB_TYPE:-hsql}Mod, driver-class-name=${DRIVER_JDBC_CLASS})
stop-embedded-server
embed-server --server-config=standalone.xml --std-out=echo
echo "Preparo datasource org.govway.datasource"
/subsystem=datasources/data-source=org.govway.datasource: add(jndi-name=java:/org.govway.datasource,enabled=true,use-java-context=true,use-ccm=true, connection-url="${JDBC_RUN_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
${JDBC_RUN_AUTH}
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=driver-class, value="${DRIVER_JDBC_CLASS}")
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=check-valid-connection-sql, value="${VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=background-validation, value=true)
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=background-validation-millis, value=60000)
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=flush-strategy, value=IdleConnections)
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=pool-prefill, value=true)
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=prepared-statements-cache-size, value=\${env.GOVWAY_DS_PSCACHESIZE:20})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=pool-use-strict-min, value=false)
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=min-pool-size, value=\${env.GOVWAY_MIN_POOL:2})
/subsystem=datasources/data-source=org.govway.datasource: write-attribute(name=max-pool-size, value=\${env.GOVWAY_MAX_POOL:50})
echo "Preparo datasource org.govway.datasource.console"
/subsystem=datasources/data-source=org.govway.datasource.console: add(jndi-name=java:/org.govway.datasource.console,enabled=true,use-java-context=true,use-ccm=true, statistics-enabled=true, connection-url="${JDBC_CONF_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
${JDBC_CONF_AUTH}
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=driver-class, value="${DRIVER_JDBC_CLASS}")
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=check-valid-connection-sql, value="${VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=background-validation, value=true)
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=background-validation-millis, value=60000)
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=flush-strategy, value=IdleConnections)
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=pool-prefill, value=true)
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=prepared-statements-cache-size, value=\${env.GOVWAY_CONF_DS_PSCACHESIZE:20})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=pool-use-strict-min, value=false)
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=min-pool-size, value=\${env.GOVWAY_CONF_MIN_POOL:2})
/subsystem=datasources/data-source=org.govway.datasource.console: write-attribute(name=max-pool-size, value=\${env.GOVWAY_CONF_MAX_POOL:10})
echo "Preparo datasource org.govway.datasource.tracciamento"
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: add(jndi-name=java:/org.govway.datasource.tracciamento,enabled=true,use-java-context=true,use-ccm=true, statistics-enabled=true, connection-url="${JDBC_TRAC_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
${JDBC_TRAC_AUTH}
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=driver-class, value="${DRIVER_JDBC_CLASS}")
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=check-valid-connection-sql, value="${VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=background-validation, value=true)
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=background-validation-millis, value=60000)
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=flush-strategy, value=IdleConnections)
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=pool-prefill, value=true)
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=prepared-statements-cache-size, value=\${env.GOVWAY_TRAC_DS_PSCACHESIZE:20})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=pool-use-strict-min, value=false)
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=min-pool-size, value=\${env.GOVWAY_TRAC_MIN_POOL:2})
/subsystem=datasources/data-source=org.govway.datasource.tracciamento: write-attribute(name=max-pool-size, value=\${env.GOVWAY_TRAC_MAX_POOL:50})
echo "Preparo datasource org.govway.datasource.statistiche"
/subsystem=datasources/data-source=org.govway.datasource.statistiche: add(jndi-name=java:/org.govway.datasource.statistiche,enabled=true,use-java-context=true,use-ccm=true, statistics-enabled=true, connection-url="${JDBC_STAT_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
${JDBC_STAT_AUTH}
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=driver-class, value="${DRIVER_JDBC_CLASS}")
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=check-valid-connection-sql, value="${VALID_CONNECTION_SQL}")
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=background-validation, value=true)
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=background-validation-millis, value=60000)
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=flush-strategy, value=IdleConnections)
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=pool-prefill, value=true)
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=prepared-statements-cache-size, value=\${env.GOVWAY_STAT_DS_PSCACHESIZE:20})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=pool-use-strict-min, value=false)
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=min-pool-size, value=\${env.GOVWAY_STAT_MIN_POOL:1})
/subsystem=datasources/data-source=org.govway.datasource.statistiche: write-attribute(name=max-pool-size, value=\${env.GOVWAY_STAT_MAX_POOL:5})
EOCLI

if [ -f ${JBOSS_HOME}/standalone/deployments/IntegrationManagerV1-${GOVWAY_FULLVERSION}.war ]
then
    case "${GOVWAY_DB_TYPE:-hsql}" in
    postgresql)
        DRIVER_JDBC="/opt/postgresql-${POSTGRES_JDBC_VERSION}.jar"
        DRIVER_JDBC_CLASS='org.postgresql.Driver'
        VALID_CONNECTION_SQL='SELECT 1;'

        JDBC_IM_RUN_URL='jdbc:postgresql://\${env.IM_DB_SERVER}/\${env.IM_DB_NAME}?\${env.IM_DS_CONN_PARAM:}'
        JDBC_IM_RUN_AUTH="/subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=user-name, value=\${env.IM_DB_USER})
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=password, value=\${env.IM_DB_PASSWORD})"

        JDBC_IM_CONF_URL='jdbc:postgresql://\${env.IM_CONF_DB_SERVER}/\${env.IM_CONF_DB_NAME}?\${env.IM_CONF_DS_CONN_PARAM:}'
        JDBC_IM_CONF_AUTH="  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=user-name, value=\${env.IM_CONF_DB_USER})
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=password, value=\${env.IM_CONF_DB_PASSWORD})"

        JDBC_IM_TRAC_URL='jdbc:postgresql://\${env.IM_TRAC_DB_SERVER}/\${env.IM_TRAC_DB_NAME}?\${env.TIM_RAC_DS_CONN_PARAM:}'
        JDBC_IM_TRAC_AUTH="/subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=user-name, value=\${env.IM_TRAC_DB_USER})
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=password, value=\${env.IM_TRAC_DB_PASSWORD})"
    ;;
    hsql|*)
        DRIVER_JDBC="opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/hsqldb.jar"
        DRIVER_JDBC_CLASS='org.hsqldb.jdbc.Driver'
        VALID_CONNECTION_SQL='SELECT 1;'

        JDBC_IM_RUN_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/\${env.IM_DB_NAME};shutdown=true"
        JDBC_IM_RUN_AUTH="/subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=user-name, value=govway)
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=password, value=govway)"

        JDBC_IM_CONF_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/\${env.IM_CONF_DB_NAME};shutdown=true"
        JDBC_IM_CONF_AUTH="/subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=user-name, value=govway)
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=password, value=govway)"

        JDBC_IM_TRAC_URL="jdbc:hsqldb:file:/opt/hsqldb-${HSQLDB_FULLVERSION}/hsqldb/database/\${env.IM_TRAC_DB_NAME};shutdown=true"
        JDBC_IM_TRAC_AUTH="/subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=user-name, value=govway)
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=password, value=govway)"
    ;;
    esac

cat - << EOCLI >> "${CLI_SCRIPT_FILE}"
  echo "Attivo socket binding per IM"
  /socket-binding-group=standard-sockets/socket-binding=http-im:add(port=${jboss.http.port:9080})
  echo "Aggiungo Worker http IM"
  /subsystem=io/worker=http-im-worker:add(task-max-threads=\${env.WILDFLY_HTTPIM_WORKER-MAX-THREADS:50})
  /subsystem=undertow/server=default-server/http-listener=imlistener:add(socket-binding=http-im, worker=http-im-worker)
  echo "Correggo max post size"
  /subsystem=undertow/server=default-server/http-listener=imlistener:write-attribute(name=max-post-size, value=\${env.WILDFLY_MAX-POST-SIZE:25485760})
  echo "Preparo datasource org.govway.datasource.runtime.imV1"
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: add(jndi-name=java:/org.govway.datasource.runtime.imV1,enabled=true,use-java-context=true,use-ccm=true, connection-url="${JDBC_IM_RUN_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
  ${JDBC_IM_RUN_AUTH}
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=driver-class, value="${DRIVER_JDBC_CLASS}")
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=check-valid-connection-sql, value="${VALID_CONNECTION_SQL}")
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=background-validation, value=true)
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=background-validation-millis, value=60000)
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=flush-strategy, value=IdleConnections)
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=pool-prefill, value=true)
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=prepared-statements-cache-size, value=\${env.IM_DS_PSCACHESIZE:20})
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=pool-use-strict-min, value=false)
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=min-pool-size, value=\${env.IM_MIN_POOL:2})
  /subsystem=datasources/data-source=org.govway.datasource.runtime.imV1: write-attribute(name=max-pool-size, value=\${env.IM_MAX_POOL:50})
  echo "Preparo datasource org.govway.datasource.config.imV1"
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: add(jndi-name=java:/org.govway.datasource.config.imV1,enabled=true,use-java-context=true,use-ccm=true, statistics-enabled=true, connection-url="${JDBC_IM_CONF_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
  ${JDBC_IM_CONF_AUTH}
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=driver-class, value="${DRIVER_JDBC_CLASS}")
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=check-valid-connection-sql, value="${VALID_CONNECTION_SQL}")
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=background-validation, value=true)
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=background-validation-millis, value=60000)
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=flush-strategy, value=IdleConnections)
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=pool-prefill, value=true)
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=prepared-statements-cache-size, value=\${env.IM_CONF_DS_PSCACHESIZE:20})
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=pool-use-strict-min, value=false)
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=min-pool-size, value=\${env.IM_CONF_MIN_POOL:2})
  /subsystem=datasources/data-source=org.govway.datasource.config.imV1: write-attribute(name=max-pool-size, value=\${env.IM_CONF_MAX_POOL:10})
  echo "Preparo datasource org.govway.datasource.tracciamento.imV1"
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: add(jndi-name=java:/org.govway.datasource.tracciamento.imV1,enabled=true,use-java-context=true,use-ccm=true, statistics-enabled=true, connection-url="${JDBC_IM_TRAC_URL}", driver-name=${GOVWAY_DB_TYPE:-hsql}Driver)
  ${JDBC_IM_TRAC_AUTH}
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=driver-class, value="${DRIVER_JDBC_CLASS}")
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=check-valid-connection-sql, value="${VALID_CONNECTION_SQL}")
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=background-validation, value=true)
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=background-validation-millis, value=60000)
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=flush-strategy, value=IdleConnections)
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=pool-prefill, value=true)
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=prepared-statements-cache-size, value=\${env.IM_TRAC_DS_PSCACHESIZE:20})
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=pool-use-strict-min, value=false)
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=min-pool-size, value=\${env.IM_TRAC_MIN_POOL:2})
  /subsystem=datasources/data-source=org.govway.datasource.tracciamento.imV1: write-attribute(name=max-pool-size, value=\${env.IM_TRAC_MAX_POOL:50})
EOCLI
fi