#!/bin/bash

REL="Undefined"

APT_CONF=${1:-$APT_CONF}
APT_CONF=${APT_CONF:?"APT_CONF is undefined!"}
APT_SRC_DIR=${2:-$APT_SRC_DIR}
APT_SRC_DIR=${APT_SRC_DIR:?"APT_SRC_DIR is undefined!"}

REPOS=$(find "${APT_SRC_DIR}" -type f -name "*.list")
for REPO in ${REPOS}; do
	apt-get  -c "${APT_CONF}" -o Dir::Etc::sourcelist="${REPO}"  -o Dir::Etc::sourceparts="-"  --just-print upgrade | grep Inst &>/dev/null ||
		{ REL="${REPO}";
		break; };
done

REL=${REL##*/}
REL=${REL%%.list}

echo "${REL}"
