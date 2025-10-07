#!/bin/bash

# Sostituisco il placeholder GOVWAY_DEFAULT_ENTITY_NAME in tutti gli SQL
sed -i -e \
"s/\${GOVWAY_DEFAULT_ENTITY_NAME}/${GOVWAY_DEFAULT_ENTITY_NAME}/g" \
/opt/${GOVWAY_DB_TYPE:-hsql}/*.sql
RET=$?

if [ $RET -ne 0 ]; then
    echo "FATAL: Errore durante l'inizializzazione degli script SQL."
    exit $RET
fi

# Gestione GOVWAY_DB_MAPPING: rimuove tabelle duplicate quando categorie condividono il DB con R
if [ -n "${GOVWAY_DB_MAPPING}" ]; then
    echo "INFO: GOVWAY_DB_MAPPING attivo: ${GOVWAY_DB_MAPPING}"

    # Converto la lista in array
    IFS=',' read -ra SHARED_CATEGORIES <<< "${GOVWAY_DB_MAPPING}"

    for CATEGORY in "${SHARED_CATEGORIES[@]}"; do
        # Rimuovo eventuali spazi
        CATEGORY=$(echo "$CATEGORY" | xargs)

        case "${CATEGORY^^}" in
            T)
                SUFFISSO="Tracciamento"
                echo "INFO: Categoria T (Tracciamento) condivide il DB con R: rimuovo tabelle duplicate da GovWay${SUFFISSO}.sql"
                sed -i \
                    -e '/CREATE TABLE db_info/,/;/d' \
                    -e '/CREATE SEQUENCE seq_db_info/d' \
                    -e '/CREATE TABLE OP2_SEMAPHORE/,/;/d' \
                    -e '/CREATE SEQUENCE seq_OP2_SEMAPHORE/d' \
                    -e '/CREATE TRIGGER trg_OP2_SEMAPHORE/,/\//d' \
                    -e '/CREATE UNIQUE INDEX idx_semaphore_1/d' \
                    -e '/CREATE TRIGGER trg_db_info/,/\//d' \
                    /opt/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql
                ;;
            S)
                SUFFISSO="Statistiche"
                echo "INFO: Categoria S (Statistiche) condivide il DB con R: rimuovo tabelle duplicate da GovWay${SUFFISSO}.sql"
                sed -i \
                    -e '/CREATE TABLE db_info/,/;/d' \
                    -e '/CREATE SEQUENCE seq_db_info/d' \
                    -e '/CREATE TABLE OP2_SEMAPHORE/,/;/d' \
                    -e '/CREATE SEQUENCE seq_OP2_SEMAPHORE/d' \
                    -e '/CREATE TRIGGER trg_OP2_SEMAPHORE/,/\//d' \
                    -e '/CREATE UNIQUE INDEX idx_semaphore_1/d' \
                    -e '/CREATE TRIGGER trg_db_info/,/\//d' \
                    /opt/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql
                ;;
            C)
                SUFFISSO="Configurazione"
                echo "INFO: Categoria C (Configurazione) condivide il DB con R: rimuovo solo OP2_SEMAPHORE da GovWay${SUFFISSO}.sql"
                sed -i \
                    -e '/CREATE TABLE OP2_SEMAPHORE/,/;/d' \
                    -e '/CREATE SEQUENCE seq_OP2_SEMAPHORE/d' \
                    -e '/CREATE TRIGGER trg_OP2_SEMAPHORE/,/\//d' \
                    -e '/CREATE UNIQUE INDEX idx_semaphore_1/d' \
                    /opt/${GOVWAY_DB_TYPE:-hsql}/GovWay${SUFFISSO}.sql
                ;;
            *)
                echo "WARN: Categoria sconosciuta '${CATEGORY}' in GOVWAY_DB_MAPPING. Categorie valide: T, S, C"
                ;;
        esac
    done
fi

echo "INFO: Scripts SQL inizializzati."
exit 0