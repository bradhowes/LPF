#!/bin/bash
set -eu

echo "-- BEGIN post-build.sh"

function process # TOP EMBED
{
    local TOP="${1}" EMBED="${2}"

    cd "${CODESIGNING_FOLDER_PATH}/${TOP}"
    ls -l

    for DIR in *; do
        BAD="${DIR}${EMBED}"
        if [[ -d "${BAD}" ]]; then
            echo "-- deleting '${BAD}'"
            rm -rf "${BAD}"
        fi
    done
}

if [[ -d "${CODESIGNING_FOLDER_PATH}/Contents/Frameworks" ]]; then
    # macOS paths
    process "/Contents/Frameworks" "/Versions/A/Frameworks"
elif [[ -d "${CODESIGNING_FOLDER_PATH}/Frameworks" ]]; then
    # iOS paths
    process "/Frameworks" "/Frameworks"
fi

echo "-- END post-build.sh"
