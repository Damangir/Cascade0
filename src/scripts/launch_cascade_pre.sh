#! /bin/bash

[ -z "$PRJHOME" ] && [ -f "$1" ] && PRJSETTINGS="$1"
[ -z "$PRJHOME" ] && [ -d "$1" ] && [ -f "${1}/project_setting.sh" ] && PRJSETTINGS="${1}/project_setting.sh"
[ -z "$PRJHOME" ] && [ -f "./project_setting.sh" ] && PRJSETTINGS="./project_setting.sh"

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh

[ -z "$PRJHOME" ] && echo "No proper settings. Are you sure you have a proper project_setting.sh file?" >&2 && exit 1

loop_index=0

for f in $(find "${PRJORIGINAL}" -mindepth 1 -maxdepth 1 -name "${PRJSUBJPATTERN}" | sort)
do
    id=$(basename $f)
    
    [ "$CASCADE_MIN_ID" \> "$id" ] && continue
    
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
[ "$CASCADE_ONLY_FAILED" ] && [ ! -e "${PRJCASCADE}/${id}/pre1.failed" ] && continue

STDOUT=${PRJCASCADE}/${id}/pre.stdout
XTRACE=${PRJCASCADE}/${id}/pre.xtrace
>$STDOUT
>$XTRACE
echo -e "${header_format}Launching ${id}${normal}"
(
printf "PRE 1\n" >>$STDOUT
printf "PRE 1\n" >>$XTRACE
bash -x ${CASCADESCRIPT}/cascade-pre1.sh -r ${PRJCASCADE}/${id} -n $mask_space $INPUT_ARG 1>>$STDOUT 2>>$XTRACE

printf "\nPRE 2\n" >>$STDOUT
printf "\nPRE 2\n" >>$XTRACE
bash -x ${CASCADESCRIPT}/cascade-pre2.sh -r ${PRJCASCADE}/${id} 1>>$STDOUT 2>>$XTRACE
if [ "$?" -ne "0" ]
then
  touch ${PRJCASCADE}/${id}/pre.failed
else
  rm -f ${PRJCASCADE}/${id}/pre.failed
fi
) &

loop_index=$(( $loop_index + 1 ))
if (( $loop_index % $PARALLEL == 0 )); then wait; fi

done
wait
FAILED_IDS=$(find -name "pre.failed" -exec dirname {} \; | xargs -n1 basename 2>/dev/null | sort )
if [ "$FAILED_IDS" ]
then
  echo "These job IDs failed:"
  printf "%s\n" $FAILED_IDS
  echo "Run the following to launch them again:"
  echo "env CASCADE_ONLY_FAILED=Y $0 $@"
else
  echo "All jobs complete succesfully"
fi
