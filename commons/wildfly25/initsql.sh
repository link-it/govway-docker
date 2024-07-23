sed -i -e \
"s/\${GOVWAY_DEFAULT_ENTITY_NAME}/${GOVWAY_DEFAULT_ENTITY_NAME}/g" \
/opt/${GOVWAY_DB_TYPE:-hsql}/*.sql
RET=$?
[ $RET -eq 0 ] && echo "INFO: Scripts SQL inizializzati."
exit $RET