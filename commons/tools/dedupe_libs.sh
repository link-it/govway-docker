#!/bin/sh
set -eu

# Deduplica i jar identici (stesso nome file e stesso contenuto) tra le lib/ dei vari tool
# sotto ${TOOLS_HOME}, spostandone una sola copia in ${TOOLS_HOME}/lib-common/ e lasciando
# un symlink relativo al suo posto. Se un jar omonimo ha contenuto diverso in tool diversi,
# non viene deduplicato: resta al suo posto, con un warning.

TOOLS_HOME="${1:?Usage: dedupe_libs.sh <tools_home>}"
COMMON_DIR="${TOOLS_HOME}/lib-common"

mkdir -p "${COMMON_DIR}"

for libdir in "${TOOLS_HOME}"/*/lib
do
    [ -d "${libdir}" ] || continue
    for jar in "${libdir}"/*
    do
        [ -f "${jar}" ] || continue
        name="$(basename "${jar}")"
        target="${COMMON_DIR}/${name}"
        if [ -e "${target}" ]
        then
            if cmp -s "${jar}" "${target}"
            then
                rm -f "${jar}"
                ln -s "../../lib-common/${name}" "${jar}"
            else
                echo "WARN: ${name} ha contenuto diverso tra tool differenti, non deduplicato: ${jar}" >&2
            fi
        else
            mv "${jar}" "${target}"
            ln -s "../../lib-common/${name}" "${jar}"
        fi
    done
done
