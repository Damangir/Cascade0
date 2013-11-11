#! /bin/bash

source $(dirname $0)/cascade-setup.sh

[ -z "$PRJHOME" ] && [ -f "$1" ] && source "$1"
[ -z "$PRJHOME" ] && [ -d "$1" ] && [ -f "${1}/project_setting.sh" ] && source "${1}/project_setting.sh"
[ -z "$PRJHOME" ] && [ -f "./project_setting.sh" ] && source ./project_setting.sh
[ -z "$PRJHOME" ] && echo "No proper settings. Are you sure you have a proper project_setting.sh file?" >&2 && exit 1

for f in $(find "${PRJCASCADE}" -mindepth 1 -maxdepth 1 -name "${PRJSUBJPATTERN}" | sort)
do
id=$(basename $f)
echo Processing $id
${CASCADESCRIPT}/cascade-main.sh -r ${f} -s $STATE_PREFIX 
done