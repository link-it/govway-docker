#!/bin/bash

alias errecho='>&2 echo'

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

EE_SUBJECT="c=it, o=govway.org, cn=${NOME}"

        errecho "Creazione End Entity per ${NOME}" 
        errecho "Creo chiave privata End Entity su ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem" 

        openssl genrsa -out ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem 2048

        cat /dev/urandom |tr -dc '[:alnum:][:digit:]_.;,@%#!^&*()+-'|head -c 16 > ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt
        openssl rsa \
        -in  ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem \
        -des3 \
        -passout file:${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt \
        -out  ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem.withpasswd

        errecho "Proteggo la chiave privata End Entity con password" 
        /bin/mv -f ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem.withpasswd ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem
        chmod 400 ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt
        chmod 400 ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem

        errecho "Creo richiesta di certificazione su ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.csr.pem" 
        EE_SUBJ_CANONICO=$(build_DN "${EE_SUBJECT}")
        openssl req -config ${WORK_DIR}/openssl_${SOGGETTO}.conf \
        -key ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.key.pem \
        -passin file:${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt \
        -new -sha256 -out ${WORK_DIR}/ca/csr/ee_${NOME_NOSPAZI}.csr.pem \
        -subj "${EE_SUBJ_CANONICO}"   

        errecho "Firmo richiesta di certificazione ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.csr.pem su ${WORK_DIR}/ca/certs/ee_${NOME_NOSPAZI}.cert.pem" 

        openssl ca -config ${WORK_DIR}/openssl_${SOGGETTO}.conf \
        -batch \
        -passin file:${WORK_DIR}/ca/private/ca_${SOGGETTO}.README.txt \
        -extensions ${TIPO}_cert -days 720 -notext -md sha256 \
        -in ${WORK_DIR}/ca/csr/ee_${NOME_NOSPAZI}.csr.pem \
        -out ${WORK_DIR}/ca/certs/ee_${NOME_NOSPAZI}.cert.pem
#        chmod 000 ${WORK_DIR}/ca/private/ee_${NOME_NOSPAZI}.README.txt
        chmod 444 ${WORK_DIR}/ca/certs/ee_${NOME_NOSPAZI}.cert.pem
}


##############################################
##############################################
################ MAIN ########################
##############################################
##############################################
PKI_DIR="${PKI_DIR:-./pki}"
FQDN="${FQDN:-test.govway.org}"
read -d.  SOGGETTO <<< "$FQDN"
CA_SUBJECT='C=it, O=govway.org, CN=GovWay CA'

#####################################
### Inizializzazione Database openssl
##################################### 
	WORK_DIR="${PKI_DIR}/CA_${SOGGETTO}"
	errecho "Creazione database CA per ${SOGGETTO}"
	mkdir -p  ${WORK_DIR}/ca/{certs,crl,newcerts,private,csr}
	chmod 700 ${WORK_DIR}/ca/private
	touch ${WORK_DIR}/ca/index.txt
	echo 'unique_subject = yes' > ${WORK_DIR}/ca/index.txt.attr
	printf "%.2x" $(( $RANDOM % 256 ))  > ${WORK_DIR}/ca/serial

cat - <<EOCONF > ${WORK_DIR}/openssl_${SOGGETTO}.conf
[ ca ]
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = ${WORK_DIR}/ca
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
RANDFILE          = \$dir/private/.rand

# The root key and root certificate.
private_key       = \$dir/private/ca_${SOGGETTO}.key.pem
certificate       = \$dir/certs/ca_${SOGGETTO}.cert.pem

# For certificate revocation lists.
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl/ca_${SOGGETTO}.crl.pem
crl_extensions    = crl_ext
default_crl_days  = 30

# SHA-1 is deprecated, so use SHA-2 instead.
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_loose

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
string_mask         = utf8only

# SHA-1 is deprecated, so use SHA-2 instead.
default_md          = sha256

# Extension to add when the -x509 option is used.
x509_extensions     = v3_ca

[ req_distinguished_name ]
# See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
countryName                     = Country Name (2 letter code)
stateOrProvinceName             = State or Province Name
localityName                    = Locality Name
0.organizationName              = Organization Name
organizationalUnitName          = Organizational Unit Name
commonName                      = Common Name
emailAddress                    = Email Address

# Optionally, specify some defaults.
countryName_default             = IT
stateOrProvinceName_default     = 
localityName_default            =
0.organizationName_default      = ${SOGGETTO}
organizationalUnitName_default  =
emailAddress_default            =

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ client_cert ]
basicConstraints = CA:FALSE
nsCertType = client
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth


[ crl_ext ]
authorityKeyIdentifier=keyid:always

[ ocsp ]
basicConstraints = CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, OCSPSigning
EOCONF

#################################################
### Creazione certificato certification authority
#################################################
	errecho "Creazione Certification Authority per ${SOGGETTO}" 
	errecho "Creo chiave privata Root CA su ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem" 

	openssl genrsa -out ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem 4096  
	

	errecho "Creo certificato Root CA su ${WORK_DIR}/ca/certs/ca_${SOGGETTO}.cert.pem" 
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

	errecho "Proteggo la chiave privata Root CA con password" 
	/bin/mv -f ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem.withpasswd ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem
	chmod 400 ${WORK_DIR}/ca/private/ca_${SOGGETTO}.key.pem

#######################################
### Preparazione certificati End Entity
#######################################
certificato_EE "${FQDN}" "server"
certificato_EE "${SOGGETTO} Client 1" "client"
certificato_EE "${SOGGETTO} Client 2" "client"

	#chmod 000 ${WORK_DIR}/ca/private/ca_${SOGGETTO}.README.txt
	chmod 755 ${WORK_DIR}/ca/private

####################################################
### Disposizione dei keystore e dei files di esempio
####################################################
mkdir ${PKI_DIR}/stores ${PKI_DIR}/esempi

keytool -keystore ${PKI_DIR}/stores/truststore_server.jks -storepass 123456 -noprompt -importcert -file ${WORK_DIR}/ca/certs/ca_${SOGGETTO}.cert.pem -alias ca_${SOGGETTO}
keytool -keystore ${PKI_DIR}/stores/truststore_server.jks -storepass 123456 -noprompt -importcert -file ${WORK_DIR}/ca/certs/ee_"${SOGGETTO}_Client_1".cert.pem -alias "${SOGGETTO} Client 1"
keytool -keystore ${PKI_DIR}/stores/truststore_server.jks -storepass 123456 -noprompt -importcert -file ${WORK_DIR}/ca/certs/ee_"${SOGGETTO}_Client_2".cert.pem -alias "${SOGGETTO} Client 2"


mkdir  ${PKI_DIR}/esempi/${SOGGETTO}_Client_1
cp ${WORK_DIR}/ca/certs/ee_"${SOGGETTO}_Client_1".cert.pem \
 ${WORK_DIR}/ca/private/ee_"${SOGGETTO}_Client_1".key.pem \
 ${WORK_DIR}/ca/private/ee_"${SOGGETTO}_Client_1".README.txt \
 ${WORK_DIR}/ca/certs/ca_${SOGGETTO}.cert.pem \
${PKI_DIR}/esempi/${SOGGETTO}_Client_1

mkdir  ${PKI_DIR}/esempi/${SOGGETTO}_Client_2
cp ${WORK_DIR}/ca/certs/ee_"${SOGGETTO}_Client_2".cert.pem \
 ${WORK_DIR}/ca/private/ee_"${SOGGETTO}_Client_2".key.pem \
 ${WORK_DIR}/ca/private/ee_"${SOGGETTO}_Client_2".README.txt \
 ${WORK_DIR}/ca/certs/ca_${SOGGETTO}.cert.pem \
${PKI_DIR}/esempi/${SOGGETTO}_Client_2

FQDN_NOSPAZI="${FQDN// /_}"
mkdir  ${PKI_DIR}/esempi/${FQDN_NOSPAZI}
cp ${WORK_DIR}/ca/certs/ee_"${FQDN_NOSPAZI}".cert.pem \
 ${WORK_DIR}/ca/private/ee_"${FQDN_NOSPAZI}".key.pem \
 ${WORK_DIR}/ca/private/ee_"${FQDN_NOSPAZI}".README.txt \
 ${WORK_DIR}/ca/certs/ca_${SOGGETTO}.cert.pem \
${PKI_DIR}/esempi/${FQDN_NOSPAZI}



chmod 400 ${WORK_DIR}/ca/private/ee_${FQDN}.README.txt

cat /dev/urandom |tr -dc '[:alnum:][:digit:]_.;,@%#!^&*()+-'|head -c 20 > ${PKI_DIR}/stores/keystore_server.README.txt
openssl pkcs12 -export -passin file:${WORK_DIR}/ca/private/ee_${FQDN}.README.txt -passout file:${PKI_DIR}/stores/keystore_server.README.txt \
-inkey ${WORK_DIR}/ca/private/ee_${FQDN}.key.pem \
-in ${WORK_DIR}/ca/certs/ee_"${FQDN}".cert.pem \
-name govway_server \
-out ${PKI_DIR}/stores/keystore_server.p12
keytool -importkeystore -srckeystore ${PKI_DIR}/stores/keystore_server.p12 -srcstoretype pkcs12 -destkeystore ${PKI_DIR}/stores/keystore_server.jks \
-srcstorepass $(cat ${PKI_DIR}/stores/keystore_server.README.txt) -deststorepass $(cat ${PKI_DIR}/stores/keystore_server.README.txt)
#keytool -keypasswd -keystore ${PKI_DIR}/stores/keystore_server.jks -alias govway_server -new $(cat ${WORK_DIR}/ca/private/ee_${FQDN}.README.txt) -storepass $(cat ${PKI_DIR}/stores/keystore_server.README.txt)
keytool -keypasswd -keystore ${PKI_DIR}/stores/keystore_server.jks -alias govway_server -new $(cat ${PKI_DIR}/stores/keystore_server.README.txt) -storepass $(cat ${PKI_DIR}/stores/keystore_server.README.txt)


        #chmod 000 ${WORK_DIR}/ca/private/ee_${FQDN}.README.txt
	#chmod 000 ${PKI_DIR}/keystore_server.README.txt
