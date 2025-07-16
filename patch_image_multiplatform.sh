#!/bin/bash

function printHelp() {
echo "Usage $(basename $0) -s <repository>:<tagname> -p <Patch directory> -t <repository>:<tagname> "
echo 
echo "Options
-s : Imposta il nome del tag ed il repository dell'immagine sorgente 
     NOTA: deve essere rispettata la sintassi <repository>:<tagname>
-p : Inserisce le patch contenute nella directory, negli archivi dell'immagine finale
-t : Imposta il nome del tag ed il repository da  utilizzare per l'immagine finale 
     NOTE:
       - deve essere rispettata la sintassi <repository>:<tagname>
       - Non può essere uguale al tag sorgente
-g : Indica l'application server utilizzato nell'immagine sorgente (valori: [tomcat9, tomca10, wildfly25, wildfly35] , default: tomcat9)

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


while getopts "ht:s:p:g:" opt; do
  case $opt in
    s) SOURCE="$OPTARG"; NO_COLON=${SOURCE//:/}
      [ ${#SOURCE} -eq ${#NO_COLON} -o "${SOURCE:0:1}" == ':' -o "${SOURCE:(-1):1}" == ':' ] && { echo "Il tag fornito \"$SOURCE\" non utilizza la sintassi <repository>:<tagname>"; exit 2; } ;;
    t) TAG="$OPTARG"; NO_COLON=${TAG//:/}
      [ ${#TAG} -eq ${#NO_COLON} -o "${TAG:0:1}" == ':' -o "${TAG:(-1):1}" == ':' ] && { echo "Il tag fornito \"$TAG\" non utilizza la sintassi <repository>:<tagname>"; exit 2; } ;;
    p) PATCHDIR="${OPTARG}"
        [ ! -d "${PATCHDIR}" ] && { echo "la directory indicata non esiste o non e' raggiungibile [${PATCHDIR}]."; exit 3; }
        [ -z "$(ls -A ${PATCHDIR})" ] && echo "ATTENZIONE: la directory [${PATCHDIR}] e' vuota."
        ;;
    g) APPSERV="${OPTARG}"; case "$APPSERV" in tomcat9);;tomcat10);;wildfly25);;wildfly35);;*) echo "Application server non supportato: $APPSERV"; exit 2;; esac ;;
    h) printHelp
      ;;
    \?)
      echo "Opzione non valida: -$opt"
      exit 1
      ;;
  esac
done
[ -z "${SOURCE}" -o -z "${PATCHDIR}" ] && printHelp
[ "${SOURCE}" == "${TAG}" ]  && printHelp


declare -a MANIFESTS=()

for platform in linux/arm64/v8 linux/amd64
do

  arch_suffix="${platform//\//_}"
  
  rm -rf buildcontext
  mkdir -p buildcontext/
  cp -fr "commons/${APPSERV:-tomcat9}" buildcontext/commons
  cp -f commons/* buildcontext/commons 2> /dev/null

    
  cp -rL ${PATCHDIR} buildcontext/PATCH

  DOCKERBUILD_OPTS=('--build-arg' "target_image=${SOURCE}_${arch_suffix}")

  DOCKERFILE="govway/${APPSERV:-tomcat9}/Dockerfile.patch"

  "${DOCKERBIN}" build "${DOCKERBUILD_OPTS[@]}"  \
  -t "${TAG}_${arch_suffix}" \
  --platform ${platform} \
  -f ${DOCKERFILE} buildcontext
  RET=$?
  [ ${RET} -eq  0 ] || exit ${RET}
  
  MANIFESTS=(${MANIFESTS[@]} "${TAG}_${arch_suffix}")

done

echo
echo "Per pubblicare sul registro l'immagine multipiattaforma, eseguire questi comandi:"
echo 
for manifest in ${MANIFEST[@]}
do
  echo  "docker push ${manifest}" 
done
echo docker manifest create --amend ${TAG} ${MANIFESTS[@]}
echo docker manifest push ${TAG}
