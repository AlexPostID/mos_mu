#!/bin/bash

APT_CONF=${1:-$APT_CONF}
APT_CONF=${APT_CONF:?"APT_CONF is undefined!"}
PATCHES_DIR=${2:-$PATCHES_DIR}
PATCHES_DIR=${PATCHES_DIR:?"PATCHES_DIR is undefined!"}
VERIFICATION_DIR=${3:-$VERIFICATION_DIR}
VERIFICATION_DIR=${VERIFICATION_DIR:?"VERIFICATION_DIR is undefined!"}
PKG_VER_FOR_VERIFICATION=${4:-$PKG_VER_FOR_VERIFICATION}
PKG_VER_FOR_VERIFICATION=${PKG_VER_FOR_VERIFICATION:?"PKG_VER_FOR_VERIFICATION is undefined!"}
IGNORE_APPLIED_PATCHES=${5:-$IGNORE_APPLIED_PATCHES}
IGNORE_APPLIED_PATCHES=${IGNORE_APPLIED_PATCHES:-"False"}

cd "${PATCHES_DIR}" &>/dev/null || exit 0

RET=0
# Check patches
PATCHES=$(find . -type f -name "*.patch" |sort)
for PATCH in ${PATCHES}; do
    cd "${PATCHES_DIR}" || exit 2
    echo -e "\n-------- ${PATCH}"
    FILES=$(cat "${PATCH}" | awk '/diff/ {getline; getline; print $2}')
    PKG=""
    # Get Package name and make sure that all affect the only one package
    for FILE in ${FILES}; do
        PACK=$(dpkg -S "${FILE}") || {
            echo "[WARN]    ${PATCH} will be skipped since target file '${FILE}' is absent";
            rm "${PATCH}"
            break; }
        PACK=$(echo -e "${PACK}" | awk '{print $1}')
        PACK=${PACK/\:/}
        [ -z "${PKG}" ] && { PKG="${PACK}"; continue; }
        [[ "${PACK}" == "${PKG}" ]] && continue
        echo "[ERROR]  ${PATCH} affects more than one package"
        let "RET=|1"
        continue
    done

    # Download new version and extract it
    PKG_PATH=${VERIFICATION_DIR}/${PKG}
    POLICY=$(apt-cache -c "${APT_CONF}" policy "${PKG}") || exit 2
    VERS_ORIG=$(echo -e "${POLICY}" | grep "${PKG_VER_FOR_VERIFICATION}" | awk '{print $2}')
    VERS=${VERS_ORIG/\:/\%3a}
    VERS_PATH=${PKG_PATH}/${VERS}
    PKG_NAME="${PKG}_${VERS}_all.deb"

    [ -d "${VERS_PATH}" ] || mkdir -p "${VERS_PATH}"
    cd "${VERS_PATH}" || exit 2
    [ -e "${PKG_NAME}" ] ||
        apt-get -q -c "${APT_CONF}" download "${PKG}" &>/dev/null || {
            echo "[ERROR]  Failed to download ${PKG}";
            let "RET|=2";
            continue; }
    [ -d "usr" ] ||
        ar p "${PKG_NAME}" data.tar.xz | tar xJ || {
            let "RET|=2";
            continue; }

    # Verify patch applying
    cd "${PKG_PATH}" || exit 2
    cp -f "${PATCHES_DIR}/${PATCH}" .
    PATCH_FILENAME=${PATCH##*/}
    PATCH_OUT=$(patch -p1 -N -r- -d "${VERS}" < "${PATCH_FILENAME}")
    RES=$?
    echo -e "${PATCH_OUT}"
    if (( "${RES}" == 0 )); then
        if [ ${IGNORE_APPLIED_PATCHES,,} != "true" ]; then
            PATCH_RES=$(grep -E "Skipping|ignored" <<< "${PATCH_OUT}")
            if [ -n "${PATCH_RES}" ]; then
                echo "Some patches look as already applied"
                echo "Please make sure that these patches were included in MU"
                echo "If you sure that it is, you can use the following flag:"
                echo ' {"ignore_applied_patches":true}'
                echo "ignoring these patches"
            fi
            echo "[ERROR]  Failed to apply ${PATCH}"
            let "RET|=4"
            continue
        fi
        # !!?? Need to be tested
        # Only the following lines should present in output:
        #    patching file usr/lib/python2.7/dist-packages/......
        #    Reversed (or previously applied) patch detected!  Skipping patch.
        #    2 out of 2 hunks ignored
        PATCH_RES=$(grep -Ev "patching|Skipping|ignored" <<< "${PATCH_RES}")
        if [ -n "${PATCH_RES}" ]; then
            echo "[ERROR]  Failed to apply ${PATCH}"
            let "RET|=4"
            continue
        fi
    fi
    echo "[OK]     Applied successfully"
done

exit "${RET}"
