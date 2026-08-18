#!/bin/bash

# Configurazione HTTPS per i connettori Tomcat (erogazioni/fruizioni/gestione).
#
# Sottocomandi:
#   config_https.sh abilitato    -> exit 0 se HTTPS è attivo (o va attivato in automatico
#                                    perché è presente materiale crittografico), exit 1
#                                    altrimenti. Usato dall'entrypoint per decidere se vale
#                                    la pena invocare tomcat-cli.sh.
#   config_https.sh prepara      -> valida le variabili, genera/converte il materiale
#                                    crittografico (self-signed, truststore da bundle CA).
#   config_https.sh cli <file>   -> accoda le direttive tomcat-cli al file indicato.
#   config_https.sh verifica     -> verifica via xmlstarlet che i connettori attesi siano
#                                    stati creati in server.xml (tomcat-cli.sh ignora
#                                    l'exit status di java, a differenza di jboss-cli.sh
#                                    che abortirebbe già da solo: per questo WildFly non
#                                    ha un sottocomando equivalente).
#
# La password del truststore (l'unica, sui quattro tipi di materiale HTTPS di Tomcat,
# priva di un attributo nativo *PasswordFile) deve già essere risolta ed esportata
# dall'entrypoint prima di invocare "prepara"/"cli": qui viene solo referenziata per nome.

govway_https_varname() {
    local base="$1" suffix="$2" suffixed="${1}_${2}"
    if [ -n "${!suffixed}" ]
    then
        echo "${suffixed}"
    else
        echo "${base}"
    fi
}

govway_https_emit() {
    printf '%s\n' "$1" >> "${HTTPS_CLI_FILE}"
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

govway_https_has_material() {
    local s v
    for s in "" _EROGAZIONI _FRUIZIONI _GESTIONE
    do
        v="GOVWAY_AS_HTTPS_CERTIFICATE${s}"; [ -n "${!v}" ] && return 0
        v="GOVWAY_AS_HTTPS_KEYSTORE${s}";    [ -n "${!v}" ] && return 0
    done
    return 1
}

govway_https_selfsigned() {
    # $1 = suffisso porta (EROGAZIONI|FRUIZIONI|GESTIONE), $2 = directory di output
    local suffix="$1" outdir="$2" cnvar sanvar validityvar cn san validity
    cnvar=$(govway_https_varname GOVWAY_AS_HTTPS_SELF_SIGNED_CN "${suffix}")
    sanvar=$(govway_https_varname GOVWAY_AS_HTTPS_SELF_SIGNED_SAN "${suffix}")
    validityvar=$(govway_https_varname GOVWAY_AS_HTTPS_SELF_SIGNED_VALIDITY "${suffix}")
    cn="${!cnvar:-localhost}"
    san="${!sanvar:-DNS:localhost,DNS:$(hostname),IP:127.0.0.1}"
    validity="${!validityvar:-825}"

    mkdir -p "${outdir}"
    if [ ! -f "${outdir}/keystore.p12" ]
    then
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout "${outdir}/key.pem" -out "${outdir}/cert.pem" \
            -days "${validity}" -subj "/CN=${cn}" \
            -addext "subjectAltName=${san}" \
            -addext "basicConstraints=critical,CA:FALSE" \
            -addext "keyUsage=digitalSignature,keyEncipherment" \
            -addext "extendedKeyUsage=serverAuth" \
        && GOVWAY_HTTPS_TMP_PASS='govway' openssl pkcs12 -export \
            -in "${outdir}/cert.pem" -inkey "${outdir}/key.pem" \
            -out "${outdir}/keystore.p12.tmp" -name govway \
            -passout env:GOVWAY_HTTPS_TMP_PASS \
        && mv -f "${outdir}/keystore.p12.tmp" "${outdir}/keystore.p12" \
        || { echo "FATAL: Configurazione HTTPS ... generazione del certificato self-signed fallita per ${suffix}."; exit 1; }
        rm -f "${outdir}/key.pem"
        echo "WARN: Configurazione HTTPS ... generato certificato self-signed per ${suffix} - USO ESCLUSIVAMENTE DI TEST: ${outdir}/cert.pem"
    fi
}

govway_https_ca_to_truststore() {
    # $1 = path del bundle PEM di CA, $2 = directory di output
    # NOTA: si usa keytool -importcert (un'invocazione per certificato), non
    # "openssl pkcs12 -export -nokeys": quest'ultimo produce un "Certificate bag"
    # che il PKCS12KeyStore di Java non riconosce come trusted-entry (KeyStore.load
    # riesce ma ks.size()==0, e SSLUtilBase.getTrustManagers fallisce poi con
    # "trustAnchors parameter must be non-empty") anche se il file è strutturalmente
    # valido e ispezionabile con openssl. keytool marca correttamente l'entry.
    local cabundle="$1" outdir="$2" tmpdir i=0 certfile
    mkdir -p "${outdir}"
    if [ ! -f "${outdir}/truststore.p12" ]
    then
        tmpdir=$(mktemp -d)
        awk -v dir="${tmpdir}" '
            /-----BEGIN CERTIFICATE-----/ { n++; f = dir "/ca-" n ".pem" }
            f { print > f }
            /-----END CERTIFICATE-----/ { close(f); f = "" }
        ' "${cabundle}"
        GOVWAY_HTTPS_TMP_PASS='govway'
        export GOVWAY_HTTPS_TMP_PASS
        for certfile in "${tmpdir}"/ca-*.pem
        do
            [ -f "${certfile}" ] || continue
            i=$((i + 1))
            "${JAVA_HOME}/bin/keytool" -importcert -noprompt \
                -alias "ca-${i}" -file "${certfile}" \
                -keystore "${outdir}/truststore.p12.tmp" -storetype PKCS12 \
                -storepass:env GOVWAY_HTTPS_TMP_PASS \
                > /dev/null \
            || { echo "FATAL: Configurazione HTTPS ... importazione del certificato CA #${i} nel truststore fallita."; rm -rf "${tmpdir}"; exit 1; }
        done
        unset GOVWAY_HTTPS_TMP_PASS
        rm -rf "${tmpdir}"
        if [ "${i}" -eq 0 ]
        then
            echo "FATAL: Configurazione HTTPS ... nessun certificato trovato in ${cabundle}."
            exit 1
        fi
        mv -f "${outdir}/truststore.p12.tmp" "${outdir}/truststore.p12"
    fi
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
    declare -Ag GOVWAY_HTTPS_EXECUTOR=( [EROGAZIONI]=https-in-worker [FRUIZIONI]=https-out-worker [GESTIONE]=https-gest-worker )
    declare -ag GOVWAY_HTTPS_USED_PORTS=()
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
    CUR_EXECUTOR="${GOVWAY_HTTPS_EXECUTOR[${suffix}]}"

    case "${CUR_PORT}" in
        8080|8081|8082|8009)
            echo "FATAL: Configurazione HTTPS ... la porta ${CUR_PORT} configurata per ${suffix} collide con un connettore HTTP/AJP esistente."
            exit 1
            ;;
    esac
    case " ${GOVWAY_HTTPS_USED_PORTS[*]} " in
        *" ${CUR_PORT} "*)
            echo "FATAL: Configurazione HTTPS ... la porta ${CUR_PORT} è già utilizzata da un altro connettore HTTPS."
            exit 1
            ;;
    esac
    GOVWAY_HTTPS_USED_PORTS+=("${CUR_PORT}")

    CUR_CERTVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE "${suffix}")
    CUR_KEYVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_KEY "${suffix}")
    CUR_CHAINVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_CHAIN "${suffix}")
    CUR_KEYPASSVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_KEY_PASSWORD "${suffix}")
    CUR_KEYPASSFILEVAR=$(govway_https_varname GOVWAY_AS_HTTPS_CERTIFICATE_KEY_PASSWORD_FILE "${suffix}")
    CUR_KEYSTOREVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE "${suffix}")
    CUR_KEYSTORETYPEVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_TYPE "${suffix}")
    CUR_KEYSTOREALIASVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_ALIAS "${suffix}")
    CUR_KEYSTOREPASSVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD "${suffix}")
    CUR_KEYSTOREPASSFILEVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEYSTORE_PASSWORD_FILE "${suffix}")
    CUR_KEYENTRYPASSVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEY_PASSWORD "${suffix}")
    CUR_KEYENTRYPASSFILEVAR=$(govway_https_varname GOVWAY_AS_HTTPS_KEY_PASSWORD_FILE "${suffix}")
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

    if [ -n "${!CUR_KEYSTOREVAR}" ] && [ -z "${!CUR_KEYSTOREPASSVAR}" ] && [ -z "${!CUR_KEYSTOREPASSFILEVAR}" ]
    then
        echo "FATAL: Configurazione HTTPS ... ${CUR_KEYSTOREPASSVAR} (o ${CUR_KEYSTOREPASSFILEVAR}) è obbligatoria quando è impostata ${CUR_KEYSTOREVAR}."
        exit 1
    fi

    CUR_OUTDIR="${CATALINA_HOME}/conf/https/${suffix,,}"

    CUR_KSTYPE=
    if [ -n "${!CUR_KEYSTOREVAR}" ]
    then
        CUR_KSTYPE="${!CUR_KEYSTORETYPEVAR:-$(govway_https_sniff_type "${!CUR_KEYSTOREVAR}")}"
    fi
    CUR_TSTYPE=
    if [ -n "${!CUR_TRUSTSTOREVAR}" ]
    then
        CUR_TSTYPE="${!CUR_TRUSTSTORETYPEVAR:-$(govway_https_sniff_type "${!CUR_TRUSTSTOREVAR}")}"
    fi
}

# --- Sottocomando: prepara ---
sottocomando_prepara() {
    risolvi_modalita
    [ "${HTTPS_ENABLED}" != true ] && return 0

    local suffix
    for suffix in "${GOVWAY_HTTPS_SUFFIXES[@]}"
    do
        govway_https_resolve_suffix "${suffix}"

        if [ -z "${!CUR_CERTVAR}" ] && [ -z "${!CUR_KEYSTOREVAR}" ]
        then
            # modo (a): self-signed, generato con openssl (MAI con generate-self-signed-certificate-host)
            govway_https_selfsigned "${suffix}" "${CUR_OUTDIR}"
        fi
        if [ "${CUR_CLIENTAUTH,,}" != none ] && [ -n "${!CUR_CACERTVAR}" ]
        then
            govway_https_ca_to_truststore "${!CUR_CACERTVAR}" "${CUR_OUTDIR}"
        fi
    done
}

# --- Sottocomando: cli <file> ---
sottocomando_cli() {
    HTTPS_CLI_FILE="$1"
    risolvi_modalita
    [ "${HTTPS_ENABLED}" != true ] && return 0

    local suffix protocols http2val keyfile_emit_var erogport
    for suffix in "${GOVWAY_HTTPS_SUFFIXES[@]}"
    do
        govway_https_resolve_suffix "${suffix}"

        # --- Connector + SSLHostConfig (comuni a tutte le modalità) ---
        govway_https_emit "# HTTPS ${suffix}: connettore sulla porta ${CUR_PORT}"
        govway_https_emit "/Server/Service/Connector:add port=${CUR_PORT}, protocol=HTTP/1.1, SSLEnabled=true, scheme=https, secure=true, connectionTimeout=20000, executor=${CUR_EXECUTOR}, maxHttpHeaderSize=\${GOVWAY_AS_MAX_HTTP_SIZE:-1048576}, maxPostSize=\${GOVWAY_AS_MAX_POST_SIZE:-10485760}, bindOnInit=false"

        protocols="${!CUR_PROTOCOLSVAR:-TLSv1.2,TLSv1.3}"
        govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig:add protocols=${protocols//,/+}"

        if [ -n "${!CUR_CIPHERSVAR}" ]
        then
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig:write-attribute ciphers=\${${CUR_CIPHERSVAR}}"
        fi

        http2val="${!CUR_HTTP2VAR}"
        if [ "${http2val^^}" = TRUE ]
        then
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/UpgradeProtocol:add className=org.apache.coyote.http2.Http2Protocol"
        fi

        # --- materiale crittografico del server (modi a/b/c) ---
        if [ -n "${!CUR_CERTVAR}" ]
        then
            # modo (b): PEM, nessuna conversione necessaria su Tomcat (supporto nativo anche con JSSE)
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:add certificateFile=\${${CUR_CERTVAR}}"
            keyfile_emit_var="${CUR_CERTVAR}"
            [ -n "${!CUR_KEYVAR}" ] && keyfile_emit_var="${CUR_KEYVAR}"
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyFile=\${${keyfile_emit_var}}"
            if [ -n "${!CUR_CHAINVAR}" ]
            then
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateChainFile=\${${CUR_CHAINVAR}}"
            fi
            if [ -n "${!CUR_KEYPASSFILEVAR}" ]
            then
                [ -n "${!CUR_KEYPASSVAR}" ] && echo "WARN: Configurazione HTTPS ... sono state impostate sia ${CUR_KEYPASSVAR} che ${CUR_KEYPASSFILEVAR}; ha priorità ${CUR_KEYPASSFILEVAR}."
                govway_https_check_file "${!CUR_KEYPASSFILEVAR}" "${CUR_KEYPASSFILEVAR}"
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyPasswordFile=\${${CUR_KEYPASSFILEVAR}}"
            elif [ -n "${!CUR_KEYPASSVAR}" ]
            then
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyPassword=\${${CUR_KEYPASSVAR}}"
            fi
        elif [ -n "${!CUR_KEYSTOREVAR}" ]
        then
            # modo (c): keystore PKCS12/JKS montato
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:add certificateKeystoreFile=\${${CUR_KEYSTOREVAR}}"
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystoreType=${CUR_KSTYPE}"
            [ -n "${!CUR_KEYSTOREALIASVAR}" ] && govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyAlias=\${${CUR_KEYSTOREALIASVAR}}"
            if [ -n "${!CUR_KEYSTOREPASSFILEVAR}" ]
            then
                [ -n "${!CUR_KEYSTOREPASSVAR}" ] && echo "WARN: Configurazione HTTPS ... sono state impostate sia ${CUR_KEYSTOREPASSVAR} che ${CUR_KEYSTOREPASSFILEVAR}; ha priorità ${CUR_KEYSTOREPASSFILEVAR}."
                govway_https_check_file "${!CUR_KEYSTOREPASSFILEVAR}" "${CUR_KEYSTOREPASSFILEVAR}"
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystorePasswordFile=\${${CUR_KEYSTOREPASSFILEVAR}}"
            else
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystorePassword=\${${CUR_KEYSTOREPASSVAR}}"
            fi
            # certificateKeyPassword: solo se l'alias ha una password diversa da quella del keystore
            # (default Tomcat: se assente, usa certificateKeystorePassword anche per la chiave)
            if [ -n "${!CUR_KEYENTRYPASSFILEVAR}" ]
            then
                [ -n "${!CUR_KEYENTRYPASSVAR}" ] && echo "WARN: Configurazione HTTPS ... sono state impostate sia ${CUR_KEYENTRYPASSVAR} che ${CUR_KEYENTRYPASSFILEVAR}; ha priorità ${CUR_KEYENTRYPASSFILEVAR}."
                govway_https_check_file "${!CUR_KEYENTRYPASSFILEVAR}" "${CUR_KEYENTRYPASSFILEVAR}"
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyPasswordFile=\${${CUR_KEYENTRYPASSFILEVAR}}"
            elif [ -n "${!CUR_KEYENTRYPASSVAR}" ]
            then
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyPassword=\${${CUR_KEYENTRYPASSVAR}}"
            fi
        else
            # modo (a): self-signed (materiale già generato da "prepara")
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:add certificateKeystoreFile=${CUR_OUTDIR}/keystore.p12"
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystoreType=PKCS12"
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeystorePassword=govway"
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig/Certificate:write-attribute certificateKeyAlias=govway"
        fi

        # --- client authentication / mTLS (modo d) ---
        if [ "${CUR_CLIENTAUTH,,}" != none ]
        then
            govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig:write-attribute certificateVerification=${CUR_CLIENTAUTH,,}"
            if [ -n "${!CUR_CACERTVAR}" ]
            then
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig:write-attribute truststoreFile=${CUR_OUTDIR}/truststore.p12"
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig:write-attribute truststoreType=PKCS12"
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig:write-attribute truststorePassword=govway"
            else
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig:write-attribute truststoreFile=\${${CUR_TRUSTSTOREVAR}}"
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig:write-attribute truststoreType=${CUR_TSTYPE}"
                # NOTA: Tomcat non ha un attributo truststorePasswordFile nativo (limite noto,
                # vedi PIANO_HTTPS_TLS.md). La password va risolta ed esportata
                # dall'entrypoint, mai qui: qui si referenzia solo il nome della variabile.
                govway_https_emit "/Server/Service/Connector[@port=\"${CUR_PORT}\"]/SSLHostConfig:write-attribute truststorePassword=\${${CUR_TRUSTSTOREPASSVAR}:-govway}"
            fi
        fi
    done

    # --- reverse proxy / forwarding: opt-in, non tocca il comportamento di default ---
    if [ "${GOVWAY_AS_HTTPS_PROXY_FORWARDING^^}" = TRUE ]
    then
        erogport="${GOVWAY_HTTPS_USED_PORTS[0]}"
        govway_https_emit "/Server/Service/Engine/Host/Valve[@className=\"org.apache.catalina.valves.RemoteIpValve\"]:write-attribute httpsServerPort=${erogport}"
    fi
}

# --- Sottocomando: verifica ---
# tomcat-cli.sh ignora l'exit status di java (a differenza di jboss-cli.sh, che abortisce
# già da solo al primo errore): qui si verifica direttamente il risultato su server.xml.
sottocomando_verifica() {
    risolvi_modalita
    [ "${HTTPS_ENABLED}" != true ] && return 0

    local suffix check
    for suffix in "${GOVWAY_HTTPS_SUFFIXES[@]}"
    do
        govway_https_resolve_suffix "${suffix}"
        check=$(xmlstarlet sel -t -v "count(/Server/Service/Connector[@port='${CUR_PORT}'][@SSLEnabled='true'])" "${CATALINA_HOME}/conf/server.xml" 2>/dev/null)
        if [ "${check}" != "1" ]
        then
            echo "FATAL: Configurazione HTTPS ... il connettore sulla porta ${CUR_PORT} (${suffix}) non risulta creato correttamente in server.xml."
            exit 1
        fi
    done
}

case "$1" in
    abilitato)
        risolvi_modalita
        if [ "${HTTPS_ENABLED}" = true ]
        then
            [ -z "${GOVWAY_AS_HTTPS_LISTENER}" ] && echo "INFO: Configurazione HTTPS ... rilevato materiale crittografico, abilitazione automatica dei listener HTTPS."
            exit 0
        else
            exit 1
        fi
        ;;
    prepara)
        sottocomando_prepara
        ;;
    cli)
        [ -n "$2" ] || { echo "FATAL: config_https.sh cli richiede il path del file .cli"; exit 1; }
        sottocomando_cli "$2"
        ;;
    verifica)
        sottocomando_verifica
        ;;
    *)
        echo "Uso: $0 {abilitato|prepara|cli <file>|verifica}"
        exit 1
        ;;
esac
