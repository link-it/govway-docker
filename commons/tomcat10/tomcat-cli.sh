#!/bin/bash

DIRNAME=$(readlink -f $(dirname "$0"))

# Setup the JVM
if [ "x$JAVA" = "x" ]; then
    if [ "x$JAVA_HOME" != "x" ]; then
        JAVA="$JAVA_HOME/bin/java"
    else
        JAVA="java"
    fi
fi

# Backup configurazione
/bin/cp -f ${CATALINA_HOME}/conf/server.xml ${CATALINA_HOME}/conf/server.xml-backup 
/bin/cp -f ${CATALINA_HOME}/conf/context.xml ${CATALINA_HOME}/conf/context.xml-backup 

# Esecuzione direttive
${JAVA} -cp ${DIRNAME} it.link.TomcatConfigCli $1
CLI_RC=$?

# Verifiche ed eventuale rollback: se l'XML prodotto non e' valido viene ripristinato
# il backup. Il ripristino e' a tutti gli effetti un fallimento, e va segnalato come tale.
RC=${CLI_RC}
if xmlstarlet fo ${CATALINA_HOME}/conf/server.xml > /tmp/server.xml 2>&1
then
    /bin/cp -f /tmp/server.xml ${CATALINA_HOME}/conf/server.xml
else
    echo "FATAL: configurazione non valida prodotta su server.xml, ripristinato il backup."
    /bin/cp -f ${CATALINA_HOME}/conf/server.xml-backup  ${CATALINA_HOME}/conf/server.xml
    RC=1
fi

if xmlstarlet fo ${CATALINA_HOME}/conf/context.xml > /tmp/context.xml 2>&1
then
    /bin/cp -f /tmp/context.xml ${CATALINA_HOME}/conf/context.xml
else
    echo "FATAL: configurazione non valida prodotta su context.xml, ripristinato il backup."
    /bin/cp -f ${CATALINA_HOME}/conf/context.xml-backup  ${CATALINA_HOME}/conf/context.xml
    RC=1
fi

exit ${RC}