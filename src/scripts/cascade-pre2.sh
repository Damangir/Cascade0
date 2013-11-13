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

source $(dirname $0)/cascade-setup.sh



while getopts “hr:l” OPTION
do
  case $OPTION in
## Subject directory
    r)
      IMAGEROOT=$OPTARG
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

IMAGEROOT=$(readlink -f $IMAGEROOT)     
    
if [ ! -d "${IMAGEROOT}" ]
then
  echo_fatal "IMAGEROOT is not a directory."
fi


set_filenames
echo "${bold}The Cascade Pre-processing step 1${normal}"

runname "Normalizing input images"
(
set -e

ALL_IMAGES=$(ls ${IMAGEROOT}/${images_dir}/brain_{flair,t1,t2,pd}.nii.gz 2>/dev/null)
for img in $ALL_IMAGES
do
  img_type=$(basename $img .nii.gz)
  transform_file=${IMAGEROOT}/${trans_dir}/${img_type}.trans
  
  ranged_img=$(range_image $img)
  if [ ! -s $ranged_img ]
  then
    [ ! -s $MASK_FOR_HISTOGRAM ] && ${FSLPREFIX}fslmaths ${BRAIN_WMGM} -mas ${MIDDLE_10} -mas ${img} -bin $MASK_FOR_HISTOGRAM
    
    $CASCADEDIR/cascade-range --input ${img} --mask ${BRAIN_WMGM} --out ${ranged_img} --no-scale     
    if [ -s $transform_file ]
    then
      $CASCADEDIR/cascade-transform --input ${ranged_img} --transform ${transform_file} --out ${ranged_img}
    else
      scale_factor=$(${FSLPREFIX}fslstats ${ranged_img} -k ${MASK_FOR_HISTOGRAM} -P 75)
      ${FSLPREFIX}fslmaths ${ranged_img} -div ${scale_factor} ${ranged_img}
    fi
  fi
done
)
rundone $?
set -e
$(dirname $0)/cascade-hyp.sh -r $IMAGEROOT
set +e