#! /bin/bash

[ -z "$PRJHOME" ] && [ -f "$1" ] && source "$1"
[ -z "$PRJHOME" ] && [ -d "$1" ] && [ -f "${1}/project_setting.sh" ] && source "${1}/project_setting.sh"
[ -z "$PRJHOME" ] && [ -f "./project_setting.sh" ] && source ./project_setting.sh
[ -z "$PRJHOME" ] && echo "No proper settings. Are you sure you have a proper project_setting.sh file?" >&2 && exit 1

if [ 1 == 2 ]
then
rm -rf ${STATE_PREFIX}* 2>/dev/null
for f in $(find "${PRJCASCADE}" -mindepth 1 -maxdepth 1 -name "${PRJSUBJPATTERN}" | sort)
do
id=$(basename $f)
echo Processing $id
${CASCADEDIR}/cascade-main.sh -r ${f} -s $STATE_PREFIX -n $STATE_PREFIX 
done
fi

rm -rf ${PRJCASCADE}/inspect/* 2>/dev/null
mkdir -p ${PRJCASCADE}/inspect
for f in $(ls ${STATE_PREFIX}*)
do
state_id=$(basename $f .nii.gz)
/home/soheil/workspace/Cascade/build/cascade-inspect -i $f -o ${PRJCASCADE}/inspect/${state_id}_
D2=$(ls ${PRJCASCADE}/inspect/${state_id}_*|wc -l)
D1=$(echo "(sqrt ( 9 + 8 * ( $D2 - 1 ) ) - 3 ) / 2"|bc)
num_image=${PRJCASCADE}/inspect/${state_id}_000.nii.gz
for elem in $(seq 1 $D1)
do
  item=${PRJCASCADE}/inspect/${state_id}_$(printf "%03d" $elem).nii.gz
  fsl5.0-fslmaths $item -div $num_image ${PRJCASCADE}/inspect/mean_$(printf "%03d" $elem)_${state_id}.nii.gz 
done

for elem in $(seq $(echo "$D1+1"|bc) $(echo "$D2-1"|bc))
do
  item=${PRJCASCADE}/inspect/${state_id}_$(printf "%03d" $elem).nii.gz
  fsl5.0-fslmaths $num_image -sub 1 -recip -mul $item ${PRJCASCADE}/inspect/cov_$(printf "%03d" $elem)_${state_id}.nii.gz 
done

done