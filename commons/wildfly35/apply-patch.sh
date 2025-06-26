#!/bin/bash -eux

for ARCHIVETOPATCH in $(ls ${JBOSS_HOME}/standalone/deployments/*.?ar)
do
    ARCHIVENAME="$(basename ${ARCHIVETOPATCH})"
    if [ -d "/opt/PATCH/${ARCHIVENAME}-${GOVWAY_FULLVERSION}.patch" -o -L "/opt/PATCH/${ARCHIVENAME}-${GOVWAY_FULLVERSION}.patch" ] 
    then

        unzip "${ARCHIVETOPATCH}" -d "/tmp/${ARCHIVENAME}.temp"
        
        cd "/opt/PATCH/${ARCHIVENAME}-${GOVWAY_FULLVERSION}.patch"

        # Applico patch testuali se presenti
        for d in $(find . -name \*.diff)
        do
            /bin/cp -f "${d}" "/tmp/${ARCHIVENAME}.temp/${d}"
            dos2unix "${d}"
            pushd "/tmp/${ARCHIVENAME}.temp/"
            patch -p0 < "${d}"
            popd
        done

        # Incorporo nuovi properties o aggiorno i presenti
        for p in $(find . -name \*.properties)
        do 
            if [ -f "/tmp/${ARCHIVENAME}.temp/${p}" ] 
            then
                cat "${p}" >> "/tmp/${ARCHIVENAME}.temp/${p}"
            else
                # assicuro la presenza di tutte le sottodirectory
                mkdir -p "/tmp/${ARCHIVENAME}.temp/$(dirname ${p})"
                /bin/cp -f "${p}" "/tmp/${ARCHIVENAME}.temp/${p}"
            fi
        done
        
        # Incorporo tutti gli eventuali altri files
        for f in $(find . -type f -and -not -name \*.properties -and -not -name \*.diff)
        do 
            # assicuro la presenza di tutte le sottodirectory
            mkdir -p "/tmp/${ARCHIVENAME}.temp/$(dirname ${f})"
            /bin/cp -f "${f}" "/tmp/${ARCHIVENAME}.temp/${f}"
        done

        cd "/tmp/${ARCHIVENAME}.temp/"
        zip -r  "${ARCHIVETOPATCH}" *
        cd ..
        rm -rf "/tmp/${ARCHIVENAME}.temp"
    fi
done


