#! /bin/bash
#  Copyright (C) 2013 Soheil Damangir - All Rights Reserved
#  You may use and distribute, but not modify this code under the terms of the
#  Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
#  under the following conditions:
#
#  Attribution — You must attribute the work in the manner specified by the
#  author or licensor (but not in any way that suggests that they endorse you
#  or your use of the work).
#  Noncommercial — You may not use this work for commercial purposes.
#  No Derivative Works — You may not alter, transform, or build upon this
#  work
#
#  To view a copy of the license, visit
#  http://creativecommons.org/licenses/by-nc-nd/3.0/
#  

usage()
{
cat << EOF
${bold}usage${normal}: $0 options

This script runs the preprocessing of the Cascade pipeline

${bold}OPTIONS$normal:
   -h      Show this message
   -r      Image root directory
   
   -l      Show license
   
EOF
}

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh

while getopts “hr:l” OPTION
do
  case $OPTION in
## Subject directory
    r)
      IMAGEROOT=$(cd $(dirname "$OPTARG") && pwd -P )
      ;;
## Help and license      
    l)
      cascade_copyright
      cascade_license
      exit 1
      ;;
    h)
      usage
      exit 1
      ;;
    ?)
      usage
      exit
      ;;
  esac
done
  
if [ ! -d "${IMAGEROOT}" ]
then
  echo_fatal "IMAGEROOT is not a directory."
fi

set_filenames

echo "${bold}The Cascade Pre-processing step 2${normal}"

runname "Normalizing input images"
(
set +e
ALL_IMAGES=$(ls ${IMAGEROOT}/${images_dir}/brain_{flair,t1,t2,pd}.nii.gz 2>/dev/null)
set -e

for img in $ALL_IMAGES
do
  ranged_img=$(range_image $img)
  [ "$BASH_SOURCE" -nt "$ranged_img" ] || continue
  
  img_type=$(basename $img .nii.gz)
  transform_file=${IMAGEROOT}/${trans_dir}/${img_type}.trans
  histogram_file=${IMAGEROOT}/${trans_dir}/${img_type}.hist
  normal_histogram=${HIST_ROOT}/$(basename $histogram_file)
  
  ${CASCADESCRIPT}/cascade-histogram-match.sh $histogram_file $normal_histogram $transform_file
  
  $CASCADEDIR/cascade-range --input ${img} --mask ${BRAIN_WMGM} --out ${ranged_img} --no-scale     
  $CASCADEDIR/cascade-transform --input ${ranged_img} --transform ${transform_file} --out ${ranged_img}
done
)
if [ $? -eq 0 ]
then
  rundone 0
else
  rundone 1
  rm ${IMAGEROOT}/${ranges_dir}/brain_*.nii.gz  >/dev/null 2>&1
  echo_fatal "Unable normalize images. Please try again."
fi

set -e
source ${CASCADESCRIPT}/cascade-std-register.sh
set +e
