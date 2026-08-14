#!/bin/bash

# Configurazione HTTPS per i listener undertow (erogazioni/fruizioni/gestione) via Elytron.
#
# Sottocomandi:
#   config_https.sh prepara      -> valida le variabili, genera/converte il materiale
#                                    crittografico (self-signed, PEM->PKCS12, truststore
#                                    da bundle CA). Va invocato con le password HTTPS
#                                    già risolte (_FILE con priorità) ed esportate
#                                    dall'entrypoint.
#   config_https.sh cli <file>   -> accoda le direttive jboss-cli al file indicato.
#
# NOTA: nessun ciclo embed-server qui dentro: il chiamante (entrypoint.sh) è responsabile
# di aprire/chiudere il blocco embed-server nel file .cli.

CONF_DIR="${JBOSS_HOME}/standalone/configuration"

govway_https_varname() {
    local base="$1" suffix="$2" suffixed="${1}_${2}"
    if [ -n "${!suffixed}" ]
    then
        echo "${suffixed}"
    else
        echo "${base}"
    fi
}

govway_https_check_file() {
    # $1 = path da verificare in lettura, $2 = nome variabile per il messaggio di errore
    if [ -n "$1" ] && [ ! -r "$1" ]
    then
        echo "FATAL: Configurazione HTTPS ... il file indicato da $2 non è leggibile dall'utente $(id -u -n): [$1]"
        exit 1
    fi
}

govway_https_sniff_type() {
    case "${1,,}" in
        *.jks|*.keystore) echo JKS ;;
        *) echo PKCS12 ;;
    esac
}

govway_https_check_pkcs12_legacy() {
    # $1 = path del file, $2 = tipo (JKS non è a rischio, si controlla solo PKCS12), $3 = nome variabile per il messaggio
    # Rileva l'OID PBES2 (1.2.840.113549.1.5.13) direttamente nei byte del file, senza
    # bisogno della password (gli identificativi di algoritmo non sono cifrati). Un
    # PKCS12 con questo algoritmo (default di OpenSSL 3.x e delle versioni recenti di
    # keytool) può non essere letto correttamente da alcune combinazioni WildFly/JDK
    # (stesso problema riscontrato lato Tomcat - vedi PIANO_HTTPS_TLS.md). Qui non
    # possiamo rigenerare il file dell'utente: meglio un FATAL esplicito che un
    # crash-loop criptico.
    local path="$1" type="$2" varname="$3" pbes2_oid
    [ -z "${path}" ] && return 0
    [ "${type^^}" = "PKCS12" ] || return 0
    pbes2_oid=$(printf '\x2a\x86\x48\x86\xf7\x0d\x01\x05\x0d')
    if grep -q -a -F "${pbes2_oid}" "${path}" 2>/dev/null
    then
        echo "FATAL: Configurazione HTTPS ... il file indicato da ${varname} usa l'algoritmo PKCS12 moderno (PBES2/AES-256)."
        echo "FATAL: Questa combinazione WildFly/JDK potrebbe non leggerlo correttamente (fallisce con 'keystore password was incorrect' anche con la password giusta)."
        echo "FATAL: Rigenerarlo con 'openssl pkcs12 -export -legacy ...' oppure con 'keytool ... -J-Dkeystore.pkcs12.legacy'."
        exit 1
    fi
}

govway_https_has_material() {
    local s v
    for s in "" _EROGAZIONI _FRUIZIONI _GESTIONE
    do
        v="GOVWAY_AS_HTTPS_CERTIFICATE${s}"; [ -n "${!v}" ] && return 0
        v="GOVWAY_AS_HTTPS_KEYSTORE${s}";    [ -n "${!v}" ] && return 0
    done
    return 1
}

# -legacy: il default di OpenSSL 3.x (PBES2/PBKDF2/AES-256) produce un PKCS12 che alcune
# combinazioni JSSE non riescono a decifrare (fallisce con "keystore password was incorrect"
# / BadPaddingException pur essendo file e password corretti, verificato con keytool).
# RC2/3DES legacy è universalmente compatibile.
govway_https_pem_to_p12() {
    # $1=certfile $2=keyfile $3=chainfile(o vuoto) $4=keypass_env(nome variabile, o vuoto) $5=outfile $6=storepass_env(nome variabile)
    local certfile="$1" keyfile="$2" chainfile="$3" keypassenv="$4" outfile="$5" storepassenv="$6"
    local chainopt=() passinopt=()
    [ -n "${chainfile}" ] && chainopt=(-certfile "${chainfile}")
    [ -n "${keypassenv}" ] && [ -n "${!keypassenv}" ] && passinopt=(-passin "env:${keypassenv}")
    openssl pkcs12 -export -legacy -inkey "${keyfile}" -in "${certfile}" "${chainopt[@]}" \
        -name govway -macalg sha1 "${passinopt[@]}" \
        -passout "env:${storepassenv}" -out "${outfile}.tmp" \
    && mv -f "${outfile}.tmp" "${outfile}"
}

govway_https_selfsigned_p12() {
    # $1=suffisso $2=outfile $3=storepass_env(nome variabile)
    local suffix="$1" outfile="$2" storepassenv="$3" cnvar sanvar validityvar cn san validity tmpdir
    cnvar=$(govway_https_varname GOVWAY_AS_HTTPS_SELF_SIGNED_CN "${suffix}")
    sanvar=$(govway_https_varname GOVWAY_AS_HTTPS_SELF_SIGNED_SAN "${suffix}")
    validityvar=$(govway_https_varname GOVWAY_AS_HTTPS_SELF_SIGNED_VALIDITY "${suffix}")
    cn="${!cnvar:-localhost}"
    san="${!sanvar:-DNS:localhost,DNS:$(hostname),IP:127.0.0.1}"
    validity="${!validityvar:-825}"

    tmpdir=$(mktemp -d)
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "${tmpdir}/key.pem" -out "${tmpdir}/cert.pem" \
        -days "${validity}" -subj "/CN=${cn}" \
        -addext "subjectAltName=${san}" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -addext "keyUsage=digitalSignature,keyEncipherment" \
        -addext "extendedKeyUsage=serverAuth" \
    && govway_https_pem_to_p12 "${tmpdir}/cert.pem" "${tmpdir}/key.pem" "" "" "${outfile}" "${storepassenv}" \
    && cp -f "${tmpdir}/cert.pem" "$(dirname "${outfile}")/cert.pem"
    local rc=$?
    rm -rf "${tmpdir}"
    if [ ${rc} -ne 0 ]
    then
        echo "FATAL: Configurazione HTTPS ... generazione del certificato self-signed fallita per ${suffix}."
        exit 1
    fi
    echo "WARN: Configurazione HTTPS ... generato certificato self-signed per ${suffix} - USO ESCLUSIVAMENTE DI TEST: $(dirname "${outfile}")/cert.pem"
}

govway_https_ca_to_truststore() {
    # $1 = path del bundle PEM di CA, $2 = outfile, $3 = storepass_env(nome variabile)
    # NOTA: "openssl pkcs12 -export -nokeys" produce un "Certificate bag" che il
    # PKCS12KeyStore di Java non riconosce come trusted-entry (KeyStore.load riesce ma
    # ks.size()==0, poi WFLYELY fallisce con "trustAnchors must be non-empty"). Si usa
    # invece keytool -importcert, un'invocazione per certificato del bundle.
    # -J-Dkeystore.pkcs12.legacy: il default moderno (PBES2/AES-256) usato da keytool
    # stesso non viene letto correttamente da questa combinazione WildFly/JDK; forza
    # la cifratura legacy RC2/3DES (stesso problema riscontrato lato Tomcat).
    local cabundle="$1" outfile="$2" storepassenv="$3" tmpdir i=0 certfile
    tmpdir=$(mktemp -d)
    awk -v dir="${tmpdir}" '
        /-----BEGIN CERTIFICATE-----/ { n++; f = dir "/ca-" n ".pem" }
        f { print > f }
        /-----END CERTIFICATE-----/ { close(f); f = "" }
    ' "${cabundle}"
    for certfile in "${tmpdir}"/ca-*.pem
    do
        [ -f "${certfile}" ] || continue
        i=$((i + 1))
        "${JAVA_HOME}/bin/keytool" -importcert -noprompt -J-Dkeystore.pkcs12.legacy \
            -alias "ca-${i}" -file "${certfile}" \
            -keystore "${outfile}.tmp" -storetype PKCS12 \
            -storepass:env "${storepassenv}" \
            > /dev/null \
        || { echo "FATAL: Configurazione HTTPS ... importazione del certificato CA #${i} nel truststore fallita."; rm -rf "${tmpdir}"; exit 1; }
    done
    rm -rf "${tmpdir}"
    if [ "${i}" -eq 0 ]
    then
        echo "FATAL: Configurazione HTTPS ... nessun certificato trovato in ${cabundle}."
        exit 1
    fi
    mv -f "${outfile}.tmp" "${outfile}"
}

# --- Risoluzione modalità di attivazione (una volta sola, valida per tutte le porte) ---
risolvi_modalita() {
    HTTPS_ENABLED=false
    HTTPS_ONLY_EROGAZIONI=false
    case "${GOVWAY_AS_HTTPS_LISTENER^^}" in
        FALSE)      HTTPS_ENABLED=false ;;
        TRUE)       HTTPS_ENABLED=true ;;
        HTTPS-8443) HTTPS_ENABLED=true; HTTPS_ONLY_EROGAZIONI=true ;;
        '')
            govway_https_has_material && HTTPS_ENABLED=true
            ;;
        *)
            echo "FATAL: Valore non consentito per la variabile GOVWAY_AS_HTTPS_LISTENER: [GOVWAY_AS_HTTPS_LISTENER=${GOVWAY_AS_HTTPS_LISTENER}]."
            echo "       Valori consentiti: [ true, false, https-8443 ]"
            exit 1
            ;;
    esac

    declare -Ag GOVWAY_HTTPS_DEFAULT_PORT=( [EROGAZIONI]=8443 [FRUIZIONI]=8444 [GESTIONE]=8445 )
    declare -Ag GOVWAY_HTTPS_SOCKET_BINDING=( [EROGAZIONI]=https [FRUIZIONI]=https-out [GESTIONE]=https-gest )
    declare -Ag GOVWAY_HTTPS_LISTENER_NAME=( [EROGAZIONI]=https [FRUIZIONI]=https-fruizioni [GESTIONE]=https-gestione )
    declare -Ag GOVWAY_HTTPS_WORKER_NAME=( [EROGAZIONI]=https-in-worker [FRUIZIONI]=https-out-worker [GESTIONE]=https-gest-worker )
    declare -Ag GOVWAY_HTTPS_WORKER_VARTAG=( [EROGAZIONI]=IN [FRUIZIONI]=OUT [GESTIONE]=GEST )
    declare -Ag GOVWAY_HTTPS_WORKER_DEFAULT=( [EROGAZIONI]=100 [FRUIZIONI]=100 [GESTIONE]=20 )
    declare -ag GOVWAY_HTTPS_SUFFIXES=()

    [ "${HTTPS_ENABLED}" != true ] && return 0

    local suffix
    for suffix in EROGAZIONI FRUIZIONI GESTIONE
    do
        [ "${HTTPS_ONLY_EROGAZIONI}" = true ] && [ "${suffix}" != EROGAZIONI ] && continue
        GOVWAY_HTTPS_SUFFIXES+=("${suffix}")
    done
}

# Risolve tutte le variabili per un singolo suffisso in variabili globali CUR_*.
# Include la validazione pre-flight (FATAL in caso di configurazione inconsistente).
govway_https_resolve_suffix() {
    local suffix="$1"

    CUR_PORTVAR=$(govway_https_varname GOVWAY_AS_HTTPS_PORT "${suffix}")
    CUR_PORT="${!CUR_PORTVAR:-${GOVWAY_HTTPS_DEFAULT_PORT[${suffix}]}}"
    CUR_SOCKET_BINDING="${GOVWAY_HTTPS_SOCKET_BINDING[${suffix}]}"
    CUR_LISTENER_NAME="${GOVWAY_HTTPS_LISTENER_NAME[${suffix}]}"
    CUR_WORKER_NAME="${GOVWAY_HTTPS_WORKER_NAME[${suffix}]}"
    CUR_WORKER_VARTAG="${GOVWAY_HTTPS_WORKER_VARTAG[${suffix}]}"
    CUR_WORKER_DEFAULT="${GOVWAY_HTTPS_WORKER_DEFAULT[${suffix}]}"

    case "${CUR_PORT}" in
        8080|8081|8082|8009)
            echo "FATAL: Configurazione HTTPS ... la porta ${CUR_PORT} configurata per ${suffix} collide con un connettore HTTP/AJP esistente."
            exit 1
            ;;
    esac

    CUR_CERTVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE "${suffix}")
    CUR_KEYVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_KEY "${suffix}")
    CUR_CHAINVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_CHAIN "${suffix}")
    CUR_KEYPASSVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_KEY_PASSWORD "${suffix}")
    CUR_KEYSTOREVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE "${suffix}")
    CUR_KEYSTORETYPEVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_TYPE "${suffix}")
    CUR_KEYSTOREALIASVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_ALIAS "${suffix}")
    CUR_KEYSTOREPASSVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD "${suffix}")
    CUR_KEYENTRYPASSVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEY_PASSWORD "${suffix}")
    CUR_CLIENTAUTHVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CLIENT_AUTH "${suffix}")
    CUR_TRUSTSTOREVAR=$(govway_https_varname GOVWAY_AS_HTTPS_TRUSTSTORE "${suffix}")
    CUR_TRUSTSTORETYPEVAR=$(govway_https_varname GOVWAY_AS_HTTPS_TRUSTSTORE_TYPE "${suffix}")
    CUR_TRUSTSTOREPASSVAR=$(govway_https_varname GOVWAY_AS_HTTPS_TRUSTSTORE_PASSWORD "${suffix}")
    CUR_CACERTVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CA_CERTIFICATE "${suffix}")
    CUR_PROTOCOLSVAR=$(govway_https_varname GOVWAY_AS_HTTPS_PROTOCOLS "${suffix}")
    CUR_CIPHERSVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CIPHERS "${suffix}")
    CUR_HTTP2VAR=$(govway_https_varname GOVWAY_AS_HTTPS_HTTP2 "${suffix}")

    if [ -n "${!CUR_CERTVAR}" ] && [ -n "${!CUR_KEYSTOREVAR}" ]
    then
        echo "FATAL: Configurazione HTTPS ... per ${suffix} sono state impostate sia ${CUR_CERTVAR} che ${CUR_KEYSTOREVAR}: le modalità PEM e keystore sono mutuamente esclusive."
        exit 1
    fi

    CUR_CLIENTAUTH="${!CUR_CLIENTAUTHVAR:-none}"
    case "${CUR_CLIENTAUTH,,}" in
        none|optional|required) : ;;
        *)
            echo "FATAL: Configurazione HTTPS ... valore non consentito per ${CUR_CLIENTAUTHVAR}: [${CUR_CLIENTAUTH}]. Valori consentiti: [ none, optional, required ]"
            exit 1
            ;;
    esac
    if [ "${CUR_CLIENTAUTH,,}" != none ] && [ -z "${!CUR_TRUSTSTOREVAR}" ] && [ -z "${!CUR_CACERTVAR}" ]
    then
        echo "FATAL: Configurazione HTTPS ... ${CUR_CLIENTAUTHVAR}=${CUR_CLIENTAUTH} richiede ${CUR_TRUSTSTOREVAR} oppure ${CUR_CACERTVAR}."
        exit 1
    fi

    govway_https_check_file "${!CUR_CERTVAR}" "${CUR_CERTVAR}"
    govway_https_check_file "${!CUR_KEYVAR}" "${CUR_KEYVAR}"
    govway_https_check_file "${!CUR_CHAINVAR}" "${CUR_CHAINVAR}"
    govway_https_check_file "${!CUR_KEYSTOREVAR}" "${CUR_KEYSTOREVAR}"
    govway_https_check_file "${!CUR_TRUSTSTOREVAR}" "${CUR_TRUSTSTOREVAR}"
    govway_https_check_file "${!CUR_CACERTVAR}" "${CUR_CACERTVAR}"

    if [ -n "${!CUR_KEYSTOREVAR}" ] && [ -z "${!CUR_KEYSTOREPASSVAR}" ]
    then
        echo "FATAL: Configurazione HTTPS ... ${CUR_KEYSTOREPASSVAR} è obbligatoria quando è impostata ${CUR_KEYSTOREVAR}."
        exit 1
    fi

    if [ -n "${!CUR_KEYSTOREVAR}" ]
    then
        govway_https_check_pkcs12_legacy "${!CUR_KEYSTOREVAR}" "${!CUR_KEYSTORETYPEVAR:-$(govway_https_sniff_type "${!CUR_KEYSTOREVAR}")}" "${CUR_KEYSTOREVAR}"
    fi
    if [ -n "${!CUR_TRUSTSTOREVAR}" ]
    then
        govway_https_check_pkcs12_legacy "${!CUR_TRUSTSTOREVAR}" "${!CUR_TRUSTSTORETYPEVAR:-$(govway_https_sniff_type "${!CUR_TRUSTSTOREVAR}")}" "${CUR_TRUSTSTOREVAR}"
    fi

    # Materiale di nostra generazione (self-signed/PEM->P12): sempre sotto CONF_DIR,
    # relative-to=jboss.server.config.dir. Materiale utente (modo c, truststore montato):
    # path assoluto così com'è, nessuna copia.
    CUR_GENERATED_P12="govway_https_$(echo "${suffix}" | tr '[:upper:]' '[:lower:]').p12"
    CUR_GENERATED_TS_P12="govway_https_truststore_$(echo "${suffix}" | tr '[:upper:]' '[:lower:]').p12"
}

# --- Sottocomando: prepara ---
# Valida le variabili e genera/converte il materiale crittografico su disco.
# Le password vanno già risolte ed esportate dal chiamante (entrypoint.sh),
# priorità _FILE compresa: qui si leggono solo per valore, mai da file.
sottocomando_prepara() {
    risolvi_modalita
    [ "${HTTPS_ENABLED}" != true ] && return 0

    local suffix keyfile
    for suffix in "${GOVWAY_HTTPS_SUFFIXES[@]}"
    do
        govway_https_resolve_suffix "${suffix}"

        if [ -n "${!CUR_CERTVAR}" ]
        then
            # modo (b): PEM -> PKCS12, Elytron non ha un tipo key-store PEM.
            # Password del p12 generato: costante "govway" (artefatto interno, non
            # persistito come segreto). GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD non si applica
            # qui: coerente con Tomcat, dove il modo (b) non richiede alcuna password.
            if [ ! -f "${CONF_DIR}/${CUR_GENERATED_P12}" ]
            then
                keyfile="${!CUR_KEYVAR:-${!CUR_CERTVAR}}"
                GOVWAY_HTTPS_TMP_PASS='govway'
                export GOVWAY_HTTPS_TMP_PASS
                govway_https_pem_to_p12 "${!CUR_CERTVAR}" "${keyfile}" "${!CUR_CHAINVAR}" \
                    "${CUR_KEYPASSVAR}" "${CONF_DIR}/${CUR_GENERATED_P12}" GOVWAY_HTTPS_TMP_PASS \
                || { echo "FATAL: Configurazione HTTPS ... conversione PEM->PKCS12 fallita per ${suffix}."; exit 1; }
                unset GOVWAY_HTTPS_TMP_PASS
            fi
        elif [ -z "${!CUR_KEYSTOREVAR}" ]
        then
            # modo (a): self-signed (password sempre costante "govway")
            if [ ! -f "${CONF_DIR}/${CUR_GENERATED_P12}" ]
            then
                GOVWAY_HTTPS_TMP_PASS='govway'
                export GOVWAY_HTTPS_TMP_PASS
                govway_https_selfsigned_p12 "${suffix}" "${CONF_DIR}/${CUR_GENERATED_P12}" GOVWAY_HTTPS_TMP_PASS
                unset GOVWAY_HTTPS_TMP_PASS
            fi
        fi
        # modo (c): keystore montato dall'utente, usato così com'è, nessuna preparazione.

        if [ "${CUR_CLIENTAUTH,,}" != none ] && [ -n "${!CUR_CACERTVAR}" ]
        then
            # modo (d) via bundle CA: password del truststore generato, costante "govway"
            # (non è un segreto: contiene solo certificati pubblici di CA).
            if [ ! -f "${CONF_DIR}/${CUR_GENERATED_TS_P12}" ]
            then
                GOVWAY_HTTPS_TMP_PASS='govway'
                export GOVWAY_HTTPS_TMP_PASS
                govway_https_ca_to_truststore "${!CUR_CACERTVAR}" "${CONF_DIR}/${CUR_GENERATED_TS_P12}" GOVWAY_HTTPS_TMP_PASS
                unset GOVWAY_HTTPS_TMP_PASS
            fi
        fi
    done
}

# --- Sottocomando: cli <file> ---
# Accoda al file indicato le direttive jboss-cli Elytron/Undertow.
sottocomando_cli() {
    local cli_file="$1"
    risolvi_modalita
    [ "${HTTPS_ENABLED}" != true ] && return 0

    local suffix ksname kmname tsname tmname sscname keymgr_passvar protocols dmrlist p ks_path ks_type ks_relative
    for suffix in "${GOVWAY_HTTPS_SUFFIXES[@]}"
    do
        govway_https_resolve_suffix "${suffix}"

        ksname="govwayKS${suffix}"
        kmname="govwayKM${suffix}"
        tsname="govwayTS${suffix}"
        tmname="govwayTM${suffix}"
        sscname="govwaySSC${suffix}"

        {
            echo "echo Configuro HTTPS ${suffix}"
            echo "/subsystem=io/worker=${CUR_WORKER_NAME}:add(task-max-threads=\${env.GOVWAY_AS_HTTPS_${CUR_WORKER_VARTAG}_WORKER_MAX_THREADS:${CUR_WORKER_DEFAULT}})"
            echo "/socket-binding-group=standard-sockets/socket-binding=${CUR_SOCKET_BINDING}:write-attribute(name=port, value=${CUR_PORT})"
        } >> "${cli_file}"

        # --- materiale crittografico del server (modi a/b/c) ---
        if [ -n "${!CUR_CERTVAR}" ] || [ -z "${!CUR_KEYSTOREVAR}" ]
        then
            # modi (a)/(b): p12 generato da noi, password costante "govway"
            ks_path="${CUR_GENERATED_P12}"
            ks_type="PKCS12"
            ks_relative="relative-to=jboss.server.config.dir, "
            echo "/subsystem=elytron/key-store=${ksname}:add(path=\"${ks_path}\", ${ks_relative}type=${ks_type}, credential-reference={clear-text=\"govway\"})" >> "${cli_file}"
            echo "/subsystem=elytron/key-manager=${kmname}:add(key-store=${ksname}, algorithm=SunX509, alias-filter=govway, credential-reference={clear-text=\"govway\"})" >> "${cli_file}"
        else
            # modo (c): keystore utente, path assoluto, nessun relative-to
            ks_type="${!CUR_KEYSTORETYPEVAR:-$(govway_https_sniff_type "${!CUR_KEYSTOREVAR}")}"
            keymgr_passvar="${CUR_KEYSTOREPASSVAR}"
            [ -n "${!CUR_KEYENTRYPASSVAR}" ] && keymgr_passvar="${CUR_KEYENTRYPASSVAR}"
            echo "/subsystem=elytron/key-store=${ksname}:add(path=\"${!CUR_KEYSTOREVAR}\", type=${ks_type}, credential-reference={clear-text=\"\${env.${CUR_KEYSTOREPASSVAR}}\"})" >> "${cli_file}"
            if [ -n "${!CUR_KEYSTOREALIASVAR}" ]
            then
                echo "/subsystem=elytron/key-manager=${kmname}:add(key-store=${ksname}, algorithm=SunX509, alias-filter=\${env.${CUR_KEYSTOREALIASVAR}}, credential-reference={clear-text=\"\${env.${keymgr_passvar}}\"})" >> "${cli_file}"
            else
                echo "/subsystem=elytron/key-manager=${kmname}:add(key-store=${ksname}, algorithm=SunX509, credential-reference={clear-text=\"\${env.${keymgr_passvar}}\"})" >> "${cli_file}"
            fi
        fi

        # --- client authentication / mTLS (modo d) ---
        if [ "${CUR_CLIENTAUTH,,}" != none ]
        then
            if [ -n "${!CUR_CACERTVAR}" ]
            then
                echo "/subsystem=elytron/key-store=${tsname}:add(path=\"${CUR_GENERATED_TS_P12}\", relative-to=jboss.server.config.dir, type=PKCS12, credential-reference={clear-text=\"govway\"})" >> "${cli_file}"
            else
                ks_type="${!CUR_TRUSTSTORETYPEVAR:-$(govway_https_sniff_type "${!CUR_TRUSTSTOREVAR}")}"
                echo "/subsystem=elytron/key-store=${tsname}:add(path=\"${!CUR_TRUSTSTOREVAR}\", type=${ks_type}, credential-reference={clear-text=\"\${env.${CUR_TRUSTSTOREPASSVAR}:govway}\"})" >> "${cli_file}"
            fi
            echo "/subsystem=elytron/trust-manager=${tmname}:add(key-store=${tsname})" >> "${cli_file}"
        fi

        # --- server-ssl-context: uno per suffisso (semplificazione rispetto alla
        # deduplicazione per-modalità-client-auth ipotizzata in fase di progetto: qui si
        # accetta qualche risorsa Elytron in più a fronte di una logica priva di casi
        # limite su condivisione key-manager/client-auth tra porte diverse) ---
        protocols="${!CUR_PROTOCOLSVAR:-TLSv1.2,TLSv1.3}"
        dmrlist="["
        local first=true
        for p in ${protocols//,/ }
        do
            [ "${first}" = true ] && first=false || dmrlist="${dmrlist},"
            dmrlist="${dmrlist}\"${p}\""
        done
        dmrlist="${dmrlist}]"

        {
            printf '/subsystem=elytron/server-ssl-context=%s:add(key-manager=%s, protocols=%s' "${sscname}" "${kmname}" "${dmrlist}"
            [ -n "${!CUR_CIPHERSVAR}" ] && printf ', cipher-suite-filter=${env.%s}' "${CUR_CIPHERSVAR}"
            if [ "${CUR_CLIENTAUTH,,}" = required ]
            then
                printf ', trust-manager=%s, need-client-auth=true' "${tmname}"
            elif [ "${CUR_CLIENTAUTH,,}" = optional ]
            then
                printf ', trust-manager=%s, want-client-auth=true' "${tmname}"
            fi
            printf ')\n'
        } >> "${cli_file}"

        echo "/subsystem=undertow/server=default-server/https-listener=${CUR_LISTENER_NAME}:add(socket-binding=${CUR_SOCKET_BINDING}, ssl-context=${sscname}, worker=${CUR_WORKER_NAME}, enable-http2=\${env.${CUR_HTTP2VAR}:false}, max-post-size=\${env.GOVWAY_AS_MAX_POST_SIZE:10485760}, max-header-size=\${env.GOVWAY_AS_MAX_HTTP_SIZE:10485760})" >> "${cli_file}"
    done
}

case "$1" in
    prepara)
        sottocomando_prepara
        ;;
    cli)
        [ -n "$2" ] || { echo "FATAL: config_https.sh cli richiede il path del file .cli"; exit 1; }
        sottocomando_cli "$2"
        ;;
    *)
        echo "Uso: $0 {prepara|cli <file>}"
        exit 1
        ;;
esac
