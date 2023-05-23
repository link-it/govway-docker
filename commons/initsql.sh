sed -i -e \
"s/\$\{GOVWAY_DEFAULT_ENTITY_NAME\}/${GOVWAY_DEFAULT_ENTITY_NAME}/" \
/opt/${GOVWAY_DB_TYPE:-hsql}/*.sql