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
CASCADE_DEBUG=1
[ "$NON_LINEAR" ] || NON_LINEAR=YES

IMAGEROOT=$(cd "$IMAGEROOT" && pwd -P )     
    
if [ ! -d "${IMAGEROOT}" ]
then
  echo_fatal "IMAGEROOT is not a directory."
fi


set_filenames

set -e

if [ ! -e "${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name PROC STD_IMAGE )" ]
then
  $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-std-register.sh -r $IMAGEROOT
fi
if [ ! -e "${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name STD_IMAGE PROC )" ]
then
  ${FSLPREFIX}invwarp --ref=${T1_BRAIN} --warp=${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name PROC STD_IMAGE ) --out=${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name STD_IMAGE PROC )
fi

set +e
ALL_IMAGES=$(ls ${IMAGEROOT}/${ranges_dir}/brain_{flair,t1,t2,pd}.nii.gz 2>/dev/null)
set -e

CLASSMASK_DIR=${SAFE_TMP_DIR}
Z_SCORE_DIR=${SAFE_TMP_DIR}
NATIVE_STATE_DIR=${SAFE_TMP_DIR}

if [ "$CASCADE_DEBUG" -ge "3" ]
then
  CLASSMASK_DIR=${IMAGEROOT}/${temp_dir}
  Z_SCORE_DIR=${IMAGEROOT}/${temp_dir}
  NATIVE_STATE_DIR=${IMAGEROOT}/${temp_dir}
fi
NATIVE_STATE_DIR=${IMAGEROOT}/${temp_dir}

${FSLPREFIX}fslmaths ${T1_BRAIN} -mul 0 ${Z_SCORE}

for img in $ALL_IMAGES
do
  IMAGE_NAME=$(sequence_name $img)
  IMAGE_TYPE=$(sequence_type $img) 
  RANGE_IMAGE=$(range_image $img)
  
  IMAGE_MODEL_M=${NATIVE_STATE_DIR}/model_${IMAGE_NAME}_mean.nii.gz
  IMAGE_MODEL_S=${NATIVE_STATE_DIR}/model_${IMAGE_NAME}_stddev.nii.gz
  
  IMAGE_Z_SCORE=${Z_SCORE_DIR}/${IMAGE_NAME}_zsc.nii.gz

  runname "Calculating model for ${IMAGE_NAME}"
  (
  [ "$BASH_SOURCE" -ot "$IMAGE_MODEL_S" ] && [ "$BASH_SOURCE" -ot "$IMAGE_MODEL_M" ] && exit 0
  rm -f "$IMAGE_MODEL_S" "$IMAGE_MODEL_M"
  for CLASS_INDEX in {2..3}
  do
    set -e
# Calculate native mean and variance
    CLASS_N=${STATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}_number.nii.gz
    CLASS_M=${STATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}_mean.nii.gz
    CLASS_S=${STATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}_stddev.nii.gz  

    C_CLASS_N=${SAFE_TMP_DIR}/native_${IMAGE_NAME}_${CLASS_INDEX}_number.nii.gz
    C_CLASS_M=${SAFE_TMP_DIR}/native_${IMAGE_NAME}_${CLASS_INDEX}_mean.nii.gz
    C_CLASS_S=${SAFE_TMP_DIR}/native_${IMAGE_NAME}_${CLASS_INDEX}_stddev.nii.gz  
    

    if [ "${NON_LINEAR}" = "YES" ]
    then
      WARP_CMD="${FSLPREFIX}applywarp --ref=$RANGE_IMAGE --warp=${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name STD_IMAGE PROC )"
      $WARP_CMD --in=$CLASS_N --out=$C_CLASS_N
      $WARP_CMD --in=$CLASS_M --out=$C_CLASS_M
      $WARP_CMD --in=$CLASS_S --out=$C_CLASS_S
    else
      register CLASS_N RANGE_IMAGE  - $(fsl_trans_name STD_IMAGE PROC ) $C_CLASS_N
      register CLASS_N RANGE_IMAGE  - $(fsl_trans_name STD_IMAGE PROC ) $C_CLASS_N
      register CLASS_N RANGE_IMAGE  - $(fsl_trans_name STD_IMAGE PROC ) $C_CLASS_N
    fi
       
    CLASS_MASK=${CLASSMASK_DIR}/class_${CLASS_INDEX}_mask.nii.gz
    ${FSLPREFIX}fslmaths ${BRAIN_PVE} -thr ${CLASS_INDEX} -uthr ${CLASS_INDEX} -bin ${CLASS_MASK}

    IMAGE_CLASS_STD_MIN=$(${FSLPREFIX}fslstats $RANGE_IMAGE -k ${BRAIN_WM} -S )
    IMAGE_CLASS_MEAN_MIN=$(${FSLPREFIX}fslstats $RANGE_IMAGE -k ${BRAIN_WM} -P 20 )

    ${FSLPREFIX}fslmaths ${C_CLASS_M} -div ${C_CLASS_N} -nan -max ${IMAGE_CLASS_MEAN_MIN} ${C_CLASS_M}
    ${FSLPREFIX}fslmaths ${C_CLASS_N} -sub 1 -div ${C_CLASS_S} -recip -sqrt -nan -thr 0 -max ${IMAGE_CLASS_STD_MIN} -min ${C_CLASS_M} ${C_CLASS_S}

    median_img=$(${FSLPREFIX}fslstats ${RANGE_IMAGE} -k ${CLASS_MASK} -p 50)
    median_model=$(${FSLPREFIX}fslstats ${C_CLASS_M} -k ${CLASS_MASK} -p 50)

    corr_ratio=$(bc -l <<< "$median_img / $median_model" )
    
    [ "$corr_ratio" ] || exit 1

    if [ -s "$IMAGE_MODEL_M" ]
    then
      ${FSLPREFIX}fslmaths ${C_CLASS_M} -mul $corr_ratio -mas ${CLASS_MASK} -add $IMAGE_MODEL_M $IMAGE_MODEL_M
    else
      ${FSLPREFIX}fslmaths ${C_CLASS_M} -mul $corr_ratio -mas ${CLASS_MASK} $IMAGE_MODEL_M
    fi

    if [ -s "$IMAGE_MODEL_S" ]
    then
      ${FSLPREFIX}fslmaths ${C_CLASS_S} -mul $corr_ratio -mas ${CLASS_MASK} -add $IMAGE_MODEL_S $IMAGE_MODEL_S
    else
      ${FSLPREFIX}fslmaths ${C_CLASS_S} -mul $corr_ratio -mas ${CLASS_MASK} $IMAGE_MODEL_S
    fi
    
  done
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    rm -f ${CUSTOM_STATE_DIR}/model_* >/dev/null 2>&1 
    echo_fatal "Unable to calculate model."
  fi

  runname "Agregating normal brain from ${IMAGE_NAME}"  
  (
  set -e
# Membership calculation
   
  if [ "$IMAGE_TYPE" == "light" ]
  then
    ${FSLPREFIX}fslmaths ${RANGE_IMAGE} -sub ${IMAGE_MODEL_M} -div ${IMAGE_MODEL_S} -mas ${BRAIN_WMGM} ${IMAGE_Z_SCORE}    
  elif [ "$IMAGE_TYPE" == "dark" ]
  then
    ${FSLPREFIX}fslmaths ${IMAGE_MODEL_M} -sub ${RANGE_IMAGE} -div ${IMAGE_MODEL_S} -mas ${BRAIN_WMGM} ${IMAGE_Z_SCORE}
  else
    ${FSLPREFIX}fslmaths ${RANGE_IMAGE} -sub ${IMAGE_MODEL_M} -abs -div ${IMAGE_MODEL_S} -mas ${BRAIN_WMGM} ${IMAGE_Z_SCORE}
  fi

  ${FSLPREFIX}fslmaths ${IMAGE_Z_SCORE} -max ${Z_SCORE} ${Z_SCORE}
  true
  )
  if [ $? -eq 0 ]
  then
    [ "$CASCADE_DEBUG" -ge "2" ] && cp ${IMAGE_Z_SCORE} ${IMAGEROOT}/${temp_dir}
    rundone 0
  else
    rundone 1
    rm -f ${Z_SCORE_DIR}/*_zsc.nii.gz ${NORMAL_MASK} >/dev/null 2>&1 
    echo_fatal "Unable to pick normal brain."
  fi
done
runname "Normalizeing"
(
set -e
${FSLPREFIX}fslmaths ${Z_SCORE} -mas ${HYP_MASK} ${SAFE_TMP_DIR}/z-masked.nii.gz
${CASCADEDIR}/cascade-statistics-filter -i ${SAFE_TMP_DIR}/z-masked.nii.gz -b 1.5 -o ${LIKELIHOOD} --property Maximum --threshold 4
${FSLPREFIX}fslmaths ${LIKELIHOOD} -sub 3 -mul -3 -exp -add 1 -recip ${PVALUEIMAGE}
${FSLPREFIX}fslmaths ${PVALUEIMAGE} -min 1 -max 0 ${PVALUEIMAGE}
)
rundone $?

