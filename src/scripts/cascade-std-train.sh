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
   -s      State image
   -m      WML mask
   -n      Updated state image
   -l      Show license
   
EOF
}

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh


while getopts “hr:s:m:n:l” OPTION
do
  case $OPTION in
## Subject directory
    r)
      IMAGEROOT=$OPTARG
      ;;
    n)
      NEWSTATEIMAGE=$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")
      ;;
    m)
      MASKIMAGE=$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")
      ;;
    s)
      STATEIMAGE=$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")
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

IMAGEROOT=$(cd "$IMAGEROOT" && pwd -P )     
    
if [ ! -d "${IMAGEROOT}" ]
then
  echo_fatal "IMAGEROOT is not a directory."
fi


set_filenames
WEIGHT_SAMPLE=1
for CLASS_INDEX in {1..3}
do
  runname "Training on $(tissue_name ${CLASS_INDEX})"
  (
  set -e
  CLASS_MASK=${SAFE_TMP_DIR}/class_traing_${CLASS_INDEX}_mask.nii.gz
  F_IMG=${SAFE_TMP_DIR}/F_image.nii.gz
  D_IMG=${SAFE_TMP_DIR}/D_image.nii.gz
  
  ${FSLPREFIX}fslmaths $(std_image ${BRAIN_PVE}) -thr ${CLASS_INDEX} -uthr ${CLASS_INDEX} -bin ${CLASS_MASK}
  if [ "$MASKIMAGE" ]
  then
    ${FSLPREFIX}fslmaths $MASKIMAGE -bin -mul -1 -add 1 -mas ${CLASS_MASK} -bin ${CLASS_MASK}
  else
    ${FSLPREFIX}fslmaths $(std_image ${HYP_MASK}) -mul -1 -add 1 -mas ${CLASS_MASK} -bin ${CLASS_MASK}
  fi
  
  set +e
  ALL_IMAGES=$(ls ${IMAGEROOT}/${std_dir}/brain_{flair,t1,t2,pd}.nii.gz 2>/dev/null)
  set -e
  
  for img in $ALL_IMAGES
  do
    IMAGE_NAME=$(sequence_name $img)
    
    CLASS_N=${STATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}_number.nii.gz
    CLASS_M=${STATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}_mean.nii.gz
    CLASS_S=${STATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}_stddev.nii.gz
    
    NEW_CLASS_N=${NEWSTATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}_number.nii.gz
    NEW_CLASS_M=${NEWSTATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}_mean.nii.gz
    NEW_CLASS_S=${NEWSTATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}_stddev.nii.gz
    
    if [ ! -e "$CLASS_N" ] ||[ ! -e "$CLASS_N" ] ||[ ! -e "$CLASS_M" ]
    then
      ${FSLPREFIX}fslmaths $(std_image ${BRAIN_PVE}) -mul 0 $CLASS_N
      cp $CLASS_N $CLASS_M
      cp $CLASS_N $CLASS_S
    fi
    
    ${FSLPREFIX}fslmaths ${CLASS_N} -add 1 -div ${CLASS_N} -recip -nan ${F_IMG}
    ${FSLPREFIX}fslmaths ${CLASS_M} -div ${CLASS_N} -sub ${img} -mul -1 -nan ${D_IMG}
  
    ${FSLPREFIX}fslmaths ${img} -mas ${CLASS_MASK} -add ${CLASS_M} ${NEW_CLASS_M}
    ${FSLPREFIX}fslmaths ${D_IMG} -mas ${CLASS_MASK} -sqr -mul ${F_IMG} -add ${CLASS_S} ${NEW_CLASS_S}
    ${FSLPREFIX}fslmaths ${CLASS_MASK} -bin -add ${CLASS_N} ${NEW_CLASS_N}
  
  done
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    rm ${NEWSTATEIMAGE}_*.nii.gz  >/dev/null 2>&1
    echo_fatal "Unable to calculate the new state. NOTE: None of the new state for any class is not usable anymore."
  fi
done
