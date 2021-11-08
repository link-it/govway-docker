#!/bin/bash -eux

for ARCHIVETOPATCH in $(ls ${JBOSS_HOME}/standalone/deployments/*.?ar)
do
    ARCHIVENAME="$(basename ${ARCHIVETOPATCH})"
    if [ -d "/opt/PATCH/${ARCHIVENAME}-${GOVWAY_FULLVERSION}.patch" ] 
    then
        # Incorporo nuovi files
        cd "/opt/PATCH/${ARCHIVENAME}-${GOVWAY_FULLVERSION}.patch"
        zip -r "${ARCHIVETOPATCH}" *; 
        # Applico patch testuali se presenti
        unzip "${ARCHIVETOPATCH}" -d "/tmp/${ARCHIVENAME}.temp"
        cd "/tmp/${ARCHIVENAME}.temp"
        for p in $(find . -name \*.diff)
        do
            dos2unix $p
            patch -p0 < $p
        done
        zip -r  "${ARCHIVETOPATCH}" *
        rm -rf "/tmp/${ARCHIVENAME}.temp"
    fi
done


