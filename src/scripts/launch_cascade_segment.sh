#! /bin/bash

[ -z "$PRJHOME" ] && [ -f "$1" ] && PRJSETTINGS="$1"
[ -z "$PRJHOME" ] && [ -d "$1" ] && [ -f "${1}/project_setting.sh" ] && PRJSETTINGS="${1}/project_setting.sh"
[ -z "$PRJHOME" ] && [ -f "./project_setting.sh" ] && PRJSETTINGS="./project_setting.sh"

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh

[ -z "$PRJHOME" ] && echo "No proper settings. Are you sure you have a proper project_setting.sh file?" >&2 && exit 1

loop_index=0

for f in $(find "${PRJCASCADE}" -mindepth 1 -maxdepth 1 -name "${PRJSUBJPATTERN}" | sort)
do
  id=$(basename $f)
  [ "$CASCADE_MIN_ID" \> "$id" ] && continue
  
  echo -e "${header_format}Launching ${id}${normal}"
  (
  echo -e "${header_format}Processing ${id}${normal}"
  rm -f ${PRJCASCADE}/${id}/segment.failed
  bash -x ${CASCADESCRIPT}/cascade-std-normal.sh -r ${f} -s $STATE_PREFIX
  if [ "$?" -ne "0" ]
  then
    touch ${PRJCASCADE}/${id}/segment.failed
  else
    rm -f ${PRJCASCADE}/${id}/segment.failed
  fi
  ) 1>${PRJCASCADE}/${id}/segment.stdout 2>${PRJCASCADE}/${id}/segment.stderr &
  
  loop_index=$(( $loop_index + 1 ))
  if (( $loop_index % $PARALLEL == 0 )); then time wait; fi
  
done
wait
FAILED_IDS=$(find -name "segment.failed" -exec dirname {} \; | xargs -n1 basename 2>/dev/null | sort )
if [ "$FAILED_IDS" ]
then
  echo "These job IDs failed:"
  printf "%s\n" $FAILED_IDS
  echo "Run the following to launch them again:"
  echo "export CASCADE_ONLY_FAILED=Y"
  echo "$0 $@"
else
  echo "All jobs complete succesfully"
fi
