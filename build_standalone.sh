#!/bin/bash

function printHelp() {
echo "Usage $(basename $0) [ -s | -h | -t <tagname> | -v <versione> ]"
echo 
echo "Options
-s : Esegue build a partire dai sorgenti presenti nel repository GitHub
-t : Imposta il nome del TAG che verra' utilizzato per l'immagine prodotta 
-v : Imposta la versione di govway da utilizzare per il build al posto di quella di default (3.0.1.rc2)
-h : Mostra questa pagina di aiuto
"
}

DOCKERBIN="$(which docker)"
if [ -z "${DOCKERBIN}" ]
then
   echo "Impossibile trovare il comando \"docker\""
   exit 2 
fi


DA_SORGENTI=
TAG=
VER=
while getopts "sht:v:" opt; do
  case $opt in
    s) DA_SORGENTI=TRUE ;;
    t) TAG="$OPTARG" ;;
    v) VER="$OPTARG" ;;
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

cp -rp ./commons/resources_standalone ./commons/catalina_wrapper.sh ./commons/ConnectorTLS_in_server.xslt ./commons/genera_certs.sh  ./commons/openssl_conf.tmpl ./target
if [ -z "$DA_SORGENTI" ]
then
   cp -rp standalone_bin/* ./target/
else
   cp -rp standalone_src/* ./target/
fi

cd target 
DOCKERBUILD_OPT=()
[ -n "$TAG" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '-t' "$TAG")
[ -n "$VER" ] && DOCKERBUILD_OPTS=(${DOCKERBUILD_OPTS[@]} '--build-arg' "govway_fullversion=$VER")
  
"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" .
