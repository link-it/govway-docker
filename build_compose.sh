#!/bin/bash

function printHelp() {
#echo "Usage $(basename $0) [ -s | -h | -t <tagname> | -v <versione> ]"
echo "Usage $(basename $0) [ -t <repository>:<tagname> | [ -v <versione> | -b <branch> ] | -h ]"
echo 
echo "Options
-t : Imposta il nome del TAG ed il repository locale utilizzati per l'immagine prodotta 
     NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-v : Imposta la versione dell'installer binario di govway da utilizzare per il build (default :3.2.0)
-b : Imposta il branch su github da utilizzare per il build (incompatibile con -v)
-h : Mostra questa pagina di aiuto
"
}

DOCKERBIN="$(which docker)"
if [ -z "${DOCKERBIN}" ]
then
   echo "Impossibile trovare il comando \"docker\""
   exit 2 
fi
DOCKERCOMPOSEBIN="$(which docker-compose)"
if [ -z "${DOCKERCOMPOSEBIN}" ]
then
   echo "Impossibile trovare il comando \"docker-compose\""
   exit 2
fi


TAG=
BRANCH=
VER=
while getopts "b:ht:v:" opt; do
  case $opt in
    b) BRANCH="$OPTARG"; [ -n "$VER" ] && { echo "Le opzioni -v e -b sono incompatibili. Impostare solo una delle due."; exit 2; } ;;
    t) TAG="$OPTARG"; NO_COLON=${TAG//:/}
		[ ${#TAG} -eq ${#NO_COLON} -o "${TAG:0:1}" == ':' -o "${TAG:(-1):1}" == ':' ] && { echo "Il tag fornito \"$TAG\" non utilizza la sintassi <repository>:<tagname>"; exit 2; } ;;
    v) VER="$OPTARG"; [ -n "$BRANCH" ] && { echo "Le opzioni -v e -b sono incompatibili. Impostare solo una delle due."; exit 2; } ;;
    h) printHelp
       exit 0
       ;;
    \?)
      echo "Opzione non valida: -$opt"
      exit 1
      ;;
  esac
done

[ -d ./target ] && rm -rf ./target
mkdir ./target

cp -rp ./commons/resources_compose ./commons/catalina_wrapper.sh ./commons/ConnectorTLS_in_server.xslt ./commons/genera_certs.sh  ./target

if [ -n "$VER" ] 
then
	cp -rp compose_bin/* ./target/
	CONTAINER_NAME=govway_${VER//\./}
	IMAGE_NAME=govway_compose:${VER}
	BUILD_ARG='govway_fullversion'
	BUILD_ARG_VALUE="$VER"

elif [ -n "$BRANCH" ]
then
	cp -rp compose_src/* ./target/
	CONTAINER_NAME=govway_${BRANCH}
	IMAGE_NAME=govway_compose:${BRANCH}
	BUILD_ARG='govway_branch'
	BUILD_ARG_VALUE="$BRANCH"

else
	# Per default eseguo un build delle immagini binarie
        cp -rp compose_bin/* ./target/
        CONTAINER_NAME=govway_320
        IMAGE_NAME=govway_compose:3.2.0
        BUILD_ARG='govway_fullversion'
        BUILD_ARG_VALUE="3.2.0"

fi
[ -n "$TAG" ] && IMAGE_NAME=${TAG}

cd target
sed -r -e "0,/container_name:.*/{s%%container_name: ${CONTAINER_NAME}%}" \
   -e "0,/image:.*/{s%%image: ${IMAGE_NAME}%}"  \
   -e "0,/${BUILD_ARG}:.*/{s%%${BUILD_ARG}: ${BUILD_ARG_VALUE}%}" \
   -e "s%sql-govway[^:]*:(.*)%sql-${CONTAINER_NAME}:\1%" \
docker-compose.yml > .docker-compose.yml.tmp
   /bin/mv -f .docker-compose.yml.tmp docker-compose.yml


"${DOCKERCOMPOSEBIN}" build
