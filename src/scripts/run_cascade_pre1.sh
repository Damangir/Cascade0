#! /bin/bash

[ -z "$PRJHOME" ] && [ -f "$1" ] && PRJSETTINGS="$1"
[ -z "$PRJHOME" ] && [ -d "$1" ] && [ -f "${1}/project_setting.sh" ] && PRJSETTINGS="${1}/project_setting.sh"
[ -z "$PRJHOME" ] && [ -f "./project_setting.sh" ] && PRJSETTINGS="./project_setting.sh"

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh

[ -z "$PRJHOME" ] && echo "No proper settings. Are you sure you have a proper project_setting.sh file?" >&2 && exit 1

for f in $(find "${PRJORIGINAL}" -mindepth 1 -maxdepth 1 -name "${PRJSUBJPATTERN}" | sort)
do
    id=$(basename $f)
    t1=$(find "$f" -iname "$PRJT1PATTERN"        |head -n 1)
    t2=$(find "$f" -iname "$PRJT2PATTERN"        |head -n 1)
    pd=$(find "$f" -iname "$PRJPDPATTERN"        |head -n 1)
 flair=$(find "$f" -iname "$PRJFLAIRPATTERN"     |head -n 1)
  mask=$(find "$f" -iname "$PRJBRAINMASKPATTERN" |head -n 1)

mask_space=$PRJBRAINMASKSPACE

if [ ! -s "$mask" ] && [ "$mask_space" != "NONE" ]
then
  echo "Brain mask image not found at $f" >&2
  continue
fi
if ! [ -s $t1 ]
then
  echo "T1 image not found at $f" >&2
  continue
fi
if [ ! -s $flair ] && [ ! -s $t2 ]
then
  echo "No FLAIR or T2 image not found at $f" >&2
  continue
fi 

INPUT_ARG=""
[ -s "$mask" ]  && INPUT_ARG="$INPUT_ARG -b $mask"
[ -s "$t1" ]    && INPUT_ARG="$INPUT_ARG -t $t1"
[ -s "$flair" ] && INPUT_ARG="$INPUT_ARG -f $flair"
[ -s "$pd" ]    && INPUT_ARG="$INPUT_ARG -p $pd"
[ -s "$t2" ]    && INPUT_ARG="$INPUT_ARG -s $t2"

mkdir -p ${PRJCASCADE}/${id}
echo -e "${header_format}Processing ${id}${normal}"
${CASCADESCRIPT}/cascade-pre1.sh -r ${PRJCASCADE}/${id} -n $mask_space $INPUT_ARG

done