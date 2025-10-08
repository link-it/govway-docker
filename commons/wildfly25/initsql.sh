#!/bin/bash

# Determino il mapping effettivo considerando GOVWAY_DB_MAPPING
declare -A db_mapping
db_mapping[RUN]="govway_db"
db_mapping[CONF]="govway_conf_db"
db_mapping[TRAC]="govway_trac_db"
db_mapping[STAT]="govway_stat_db"

# Se GOVWAY_DB_MAPPING è definito, aggiorno il mapping
if [ -n "${GOVWAY_DB_MAPPING}" ]; then
    IFS=',' read -ra SHARED_CATEGORIES <<< "${GOVWAY_DB_MAPPING}"
    for CATEGORY in "${SHARED_CATEGORIES[@]}"; do
        CATEGORY=$(echo "$CATEGORY" | xargs)
        case "${CATEGORY^^}" in
            T) db_mapping[TRAC]="govway_db" ;;
            S) db_mapping[STAT]="govway_db" ;;
            C) db_mapping[CONF]="govway_db" ;;
        esac
    done
fi

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

# Aggiusto l'SQL per i database MySQL e MariaDB
if [ "${GOVWAY_DB_TYPE:-hsql}" == 'mysql' -o "${GOVWAY_DB_TYPE:-hsql}" == 'mariadb' ]; then
    echo "INFO: Applicazione trasformazioni SQL per MySQL/MariaDB"

    for SQL_FILE in /opt/${GOVWAY_DB_TYPE:-hsql}/*.sql; do
        [ ! -f "$SQL_FILE" ] && continue

        # Impostazione sql_mode per MySQL 8
        SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'
        sed -i -r -e "s/^SET @@SESSION.sql_mode=(.*)/-- SET @@SESSION.sql_mode=\1\n\n-- Per MySQL 8\nSET @@SESSION.sql_mode='${SQL_MODE}';/" "$SQL_FILE"

        # I COMMENT delle colonne e delle tabelle contengono il carattere apice con escape; "\'"
        # sembra che questo causi dei problemi nell'interpretare correttamente lo script al client
        # Sostituisco la coppia di caratteri con uno spazio singolo
        sed -i -e "/COMMENT/s%\\\'% %g" "$SQL_FILE"
    done
fi

echo ""
echo "INFO: Scripts SQL inizializzati per database tipo: ${GOVWAY_DB_TYPE:-hsql}"
echo ""
echo "======================================================================"
echo "  GUIDA PER L'INIZIALIZZAZIONE MANUALE DEI DATABASE"
echo "======================================================================"
echo ""
echo "  Eseguire i seguenti script SQL sui rispettivi database:"
echo ""
echo "  Script SQL                                          Database"
echo "  --------------------------------------------------  ----------------"
echo "  GovWay.sql + GovWay_init.sql                     -> ${db_mapping[RUN]}"
echo "  GovWayConfigurazione.sql + GovWayConfigurazione_init.sql -> ${db_mapping[CONF]}"
echo "  GovWayTracciamento.sql + GovWayTracciamento_init.sql   -> ${db_mapping[TRAC]}"
echo "  GovWayStatistiche.sql + GovWayStatistiche_init.sql    -> ${db_mapping[STAT]}"
echo ""
echo "  Percorso script: /opt/${GOVWAY_DB_TYPE:-hsql}/"
echo ""
echo "======================================================================"
exit 0