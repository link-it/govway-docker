#!/bin/bash

function printHelp() {
echo "Usage $(basename $0) -s <repository>:<tagname> -p <Patch directory> [ -t <repository>:<tagname> ]"
echo 
echo "Options
-s : Imposta il nome del tag ed il repository dell'immagine sorgente 
     NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-p : Inserisce le patch contenute nella directory, negli archivi dell'immagine finale
-t : Imposta il nome del tag ed il repository da  utilizzare per l'immagine finale 
     NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-h : Mostra questa pagina di aiuto
"
exit 0
}

DOCKERBIN="$(which docker)"
if [ -z "${DOCKERBIN}" ]
then
   echo "Impossibile trovare il comando \"docker\""
   exit 2 
fi


while getopts "ht:s:p:" opt; do
  case $opt in
    s) SOURCE="$OPTARG"; NO_COLON=${SOURCE//:/}
      [ ${#SOURCE} -eq ${#NO_COLON} -o "${SOURCE:0:1}" == ':' -o "${SOURCE:(-1):1}" == ':' ] && { echo "Il tag fornito \"$SOURCE\" non utilizza la sintassi <repository>:<tagname>"; exit 2; } ;;
    t) TAG="$OPTARG"; NO_COLON=${TAG//:/}
      [ ${#TAG} -eq ${#NO_COLON} -o "${TAG:0:1}" == ':' -o "${TAG:(-1):1}" == ':' ] && { echo "Il tag fornito \"$TAG\" non utilizza la sintassi <repository>:<tagname>"; exit 2; } ;;
    p) PATCHDIR="${OPTARG}"
        [ ! -d "${PATCHDIR}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${PATCHDIR}]."; exit 3; }
        [ -z "$(ls -A ${PATCHDIR})" ] && echo "ATTENZIONE: la directory [${PATCHDIR}] e' vuota."
        ;;
    h) printHelp
       ;;
    \?)
      echo "Opzione non valida: -$opt"
      exit 1
      ;;
  esac
done
[ -z "${SOURCE}" -o -z "${PATCHDIR}" ] && printHelp


rm -rf buildcontext
mkdir -p buildcontext/
cp -fr commons buildcontext/


  
cp -rL ${PATCHDIR} buildcontext/PATCH

"${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}" \
--build-arg target_image=${SOURCE} \
-t "${TAG:-$SOURCE}" \
-f govway/Dockerfile.patch buildcontext
exit $?

