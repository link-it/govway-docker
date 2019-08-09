#!/bin/bash

function printHelp() {
#echo "Usage $(basename $0) [ -s | -h | -t <tagname> | -v <versione> ]"
echo "Usage $(basename $0) [ -t <repository>:<tagname> | [ -v <versione> | -b <branch> ] | -h ]"
echo 
echo "Options
-t : Imposta il nome del TAG ed il repository locale utilizzati per l'immagine prodotta 
     NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-v : Imposta la versione dell'installer binario di govway da utilizzare per il build (default :3.1.1)
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

cp -rp ./commons/resources_standalone ./commons/catalina_wrapper.sh ./commons/ConnectorTLS_in_server.xslt ./commons/genera_certs.sh  ./target
DOCKERBUILD_OPT=()
[ -n "$TAG" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '-t' "$TAG")
if [ -n "$VER" ] 
then
	cp -rp standalone_bin/* ./target/
	DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_fullversion=$VER")
elif [ -n "$BRANCH" ]
then
	cp -rp standalone_src/* ./target/
	DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_branch=$BRANCH")
else
	# Per default eseguo un build delle immagini binarie
        cp -rp standalone_bin/* ./target/
fi

cd target 
"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" .
