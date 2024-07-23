#!/bin/bash

DIRNAME=$(readlink -f $(dirname "$0"))

# Setup the JVM
if [ "x$JRUNSCRIPT" = "x" ]; then
    if [ "x$JAVA_HOME" != "x" ]; then
        JRUNSCRIPT="$JAVA_HOME/bin/jrunscript"
    else
        JRUNSCRIPT="jrunscript"
    fi
fi

# Backup configurazione
/bin/cp -f ${CATALINA_HOME}/conf/server.xml ${CATALINA_HOME}/conf/server.xml-backup 
/bin/cp -f ${CATALINA_HOME}/conf/context.xml ${CATALINA_HOME}/conf/context.xml-backup 

# Esecuzione direttive
${JRUNSCRIPT} -f ${DIRNAME}/tomcat_config_cli.js $1

# Verifiche ed eventuale rollback
if xmlstarlet fo ${CATALINA_HOME}/conf/server.xml > /tmp/server.xml 2>&1
then
    /bin/cp -f /tmp/server.xml ${CATALINA_HOME}/conf/server.xml
else
    /bin/cp -f ${CATALINA_HOME}/conf/server.xml-backup  ${CATALINA_HOME}/conf/server.xml
fi

if xmlstarlet fo ${CATALINA_HOME}/conf/context.xml > /tmp/context.xml 2>&1
then
    /bin/cp -f /tmp/context.xml ${CATALINA_HOME}/conf/context.xml
else
    /bin/cp -f ${CATALINA_HOME}/conf/context.xml-backup  ${CATALINA_HOME}/conf/context.xml
fi