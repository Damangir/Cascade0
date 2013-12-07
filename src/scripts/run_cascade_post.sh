#! /bin/bash

[ -z "$PRJHOME" ] && [ -f "$1" ] && PRJSETTINGS="$1"
[ -z "$PRJHOME" ] && [ -d "$1" ] && [ -f "${1}/project_setting.sh" ] && PRJSETTINGS="${1}/project_setting.sh"
[ -z "$PRJHOME" ] && [ -f "./project_setting.sh" ] && PRJSETTINGS="./project_setting.sh"

source $(dirname $0)/cascade-setup.sh

[ -z "$PRJHOME" ] && echo "No proper settings. Are you sure you have a proper project_setting.sh file?" >&2 && exit 1

for f in $(find "${PRJCASCADE}" -maxdepth 1 -name "${PRJSUBJPATTERN}" | sort)
do
  id=$(basename $f)
  echo -e "${header_format}Processing ${id}${normal}"
  ${CASCADESCRIPT}/cascade-post.sh -c $CONF -p $MINSIZE -r ${f}
done
