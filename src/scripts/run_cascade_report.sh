#! /bin/bash

source $(dirname $0)/cascade-setup.sh

[ -z "$PRJHOME" ] && [ -f "$1" ] && source "$1"
[ -z "$PRJHOME" ] && [ -d "$1" ] && [ -f "${1}/project_setting.sh" ] && source "${1}/project_setting.sh"
[ -z "$PRJHOME" ] && [ -f "./project_setting.sh" ] && source ./project_setting.sh
[ -z "$PRJHOME" ] && echo "No proper settings. Are you sure you have a proper project_setting.sh file?" >&2 && exit 1

>$RESULT
for f in $(find "${PRJCASCADE}" -maxdepth 1 -name "${PRJSUBJPATTERN}" | sort)
do
  id=$(basename $f)
  echo Processing $id
  time ${CASCADESCRIPT}/cascade-report.sh -c $CONF -p $MINSIZE -r ${f}
  if ! [ -s $RESULT ]
  then
    cat ${f}/report/report.csv >> $RESULT
  else
    tail -n+2 ${f}/report/report.csv >> $RESULT
  fi
done
