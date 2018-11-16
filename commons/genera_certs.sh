#!/bin/bash


function build_RDN {
T="$1"
V="$2"
RDN=

shopt -s extglob
T="${T##+([[:space:]])}"
V="${V%%+([[:space:]])}"

[ -n "${T}" -a -n "${V}" ] && RDN="${T^^}=${V//\//\\/}"
echo "$RDN"
}


function build_DN {
SUBJ="$1"

if [ -n "${SUBJ}" ]
then
        while IFS='=' read -d, TAG VAL
        do
                DN="${DN}/$(build_RDN "$TAG" "$VAL")"
        done <<<"${SUBJ},"

        if [ ${DN:0:2} == "//" ]
        then
                DN=
                while IFS='=' read -d/ TAG VAL
                do
                        DN="${DN}/$(build_RDN "$TAG" "$VAL")"
                done <<<"${SUBJ:1}/"
        fi
fi

echo "$DN"

}

function certificato_EE {
NOME="$1"
TIPO="$2"
NOME_NOSPAZI="${NOME// /_}"

EE_SUBJECT="c=it, o=govway.org, cn=$NOME"

        echo "Creazione End Entity per ${NOME}"
        echo "Creo chiave privata End Entity su ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem"

        openssl genrsa -out ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem 2048

        cat /dev/urandom |tr -dc '[:alnum:][:digit:]_.;,@%#!^&*()+-'|head -c 16 > ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt
        openssl rsa \
        -in  ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem \
        -aes128 \
        -passout file:${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt \
        -out  ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem.withpasswd

        echo "Proteggo la chiave privata End Entity con password"
        /bin/mv -f ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem.withpasswd ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem
        chmod 400 ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt
        chmod 400 ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem

        echo "Creo richiesta di certificazione su ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.csr.pem"
        EE_SUBJ_CANONICO=$(build_DN "${EE_SUBJECT}")
        openssl req -config ${WORK_DIR}/openssl_${SOGGETTO}.conf \
        -key ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem \
        -passin file:${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt \
        -new -sha256 -out ${WORK_DIR}/ca/csr/ee_${NOME_NOSPAZI}.csr.pem \
        -subj "${EE_SUBJ_CANONICO}"   

        echo "Firmo richiesta di certificazione ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.csr.pem su ${WORK_DIR}/ca/certs/ee_${NOME_NOSPAZI}.cert.pem"

        openssl ca -config ${WORK_DIR}/openssl_${SOGGETTO}.conf \
        -batch \
        -passin file:${WORK_DIR}/ca/private/ca_${SOGGETTO}.README.txt \
        -extensions ${TIPO}_cert -days 720 -notext -md sha256 \
        -in ${WORK_DIR}/ca/csr/ee_${NOME_NOSPAZI}.csr.pem \
        -out ${WORK_DIR}/ca/certs/ee_${NOME_NOSPAZI}.cert.pem
        chmod 000 ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt
        chmod 444 ${WORK_DIR}/ca/certs/ee_${NOME_NOSPAZI}.cert.pem
}


##############################################
##############################################
################ MAIN ########################
##############################################
##############################################
PKI_DIR="${PKI_DIR:-/etc/govway/pki}"

if [ -f ${PKI_DIR}/INFO.txt ]
then
	. ${PKI_DIR}/INFO.txt
else
	FQDN='govway_server.test.it'	
fi
read -d.  SOGGETTO <<< "$FQDN"

CA_SUBJECT='C=it, O=govway.org, CN=GovWay CA'

	#WORK_DIR="$(readlink -f $(dirname $0))/${SOGGETTO}"
	#CONF_DIR="$(readlink -f $(dirname $0))/../conf"

	CONF_DIR="$(readlink -f $(dirname $0))"
	WORK_DIR="${PKI_DIR}/CA_${SOGGETTO}"
	echo "Creazione database CA per ${SOGGETTO}"
	mkdir -p  ${WORK_DIR}/ca/{certs,crl,newcerts,private,csr}
	chmod 700 ${WORK_DIR}/ca/private
	touch ${WORK_DIR}/ca/index.txt
	echo 'unique_subject = yes' > ${WORK_DIR}/ca/index.txt.attr
	printf "%.2x" $(( $RANDOM % 256 ))  > ${WORK_DIR}/ca/serial
	sed -e "s#@WORK_DIR@#${WORK_DIR}#g" -e "s#@SOGGETTO@#${SOGGETTO}#" ${CONF_DIR}/openssl_conf.tmpl > ${WORK_DIR}/openssl_${SOGGETTO}.conf

	echo "Creazione Certification Authority per ${SOGGETTO}"
	echo "Creo chiave privata Root CA su ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem"

	openssl genrsa -out ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem 4096  
	

	echo "Creo certificato Root CA su ${WORK_DIR}/ca/certs/ca_${SOGGETTO}.cert.pem"
	CA_SUBJ_CANONICO=$(build_DN "${CA_SUBJECT}")
	openssl req -config ${WORK_DIR}/openssl_${SOGGETTO}.conf \
	-key ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem \
	-new -x509 -days 7300  -extensions v3_ca \
	-out ${WORK_DIR}/ca/certs/ca_${SOGGETTO}.cert.pem \
	-subj "${CA_SUBJ_CANONICO}"
	chmod 444 ${WORK_DIR}/ca/certs/ca_${SOGGETTO}.cert.pem

	cat /dev/urandom |tr -dc '[:alnum:][:digit:]_.;,@%#!^&*()+-'|head -c 20 > ${WORK_DIR}/ca/private/ca_${SOGGETTO}.README.txt
        openssl rsa \
        -in  ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem \
	-aes256 \
	-passout file:${WORK_DIR}/ca/private/ca_${SOGGETTO}.README.txt \
        -out  ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem.withpasswd

	echo "Proteggo la chiave privata Root CA con password"
	/bin/mv -f ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem.withpasswd ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem
	chmod 400 ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem

certificato_EE "${FQDN}" "server"
certificato_EE "${SOGGETTO} Client 1" "client"
certificato_EE "${SOGGETTO} Client 2" "client"

	chmod 000 ${WORK_DIR}/ca/private/ca_${SOGGETTO}.README.txt


keytool -keystore ${PKI_DIR}/truststore_server.jks -storepass 123456 -noprompt -importcert -file ${WORK_DIR}/ca/certs/ca_${SOGGETTO}.cert.pem -alias ca_${SOGGETTO}
keytool -keystore ${PKI_DIR}/truststore_server.jks -storepass 123456 -noprompt -importcert -file ${WORK_DIR}/ca/certs/ee_"${SOGGETTO}_Client_1".cert.pem -alias "${SOGGETTO} Client 1"
keytool -keystore ${PKI_DIR}/truststore_server.jks -storepass 123456 -noprompt -importcert -file ${WORK_DIR}/ca/certs/ee_"${SOGGETTO}_Client_2".cert.pem -alias "${SOGGETTO} Client 2"

        chmod 400 ${WORK_DIR}/ca/private/ee_${FQDN}.README.txt

cat /dev/urandom |tr -dc '[:alnum:][:digit:]_.;,@%#!^&*()+-'|head -c 20 > ${PKI_DIR}/keystore_server.README.txt
openssl pkcs12 -export -passin file:${WORK_DIR}/ca/private/ee_${FQDN}.README.txt -passout file:${PKI_DIR}/keystore_server.README.txt \
-inkey ${WORK_DIR}/ca/private/ee_${FQDN}.key.pem \
-in ${WORK_DIR}/ca/certs/ee_"${FQDN}".cert.pem \
-name govway_server \
-out ${PKI_DIR}/keystore_server.p12
keytool -importkeystore -srckeystore ${PKI_DIR}/keystore_server.p12 -srcstoretype pkcs12 -destkeystore ${PKI_DIR}/keystore_server.jks \
-srcstorepass $(cat ${PKI_DIR}/keystore_server.README.txt) -deststorepass $(cat ${PKI_DIR}/keystore_server.README.txt)
keytool -keypasswd -keystore ${PKI_DIR}/keystore_server.jks -alias govway_server -new $(cat ${WORK_DIR}/ca/private/ee_${FQDN}.README.txt) -storepass $(cat ${PKI_DIR}/keystore_server.README.txt)

        chmod 000 ${WORK_DIR}/ca/private/ee_${FQDN}.README.txt
	chmod 000 ${PKI_DIR}/keystore_server.README.txt
