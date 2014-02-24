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
    
if [ ! -d "${IMAGEROOT}" ]
then
  echo_fatal "IMAGEROOT is not a directory."
fi

set_filenames

echo "${bold}Calculating transformation to MNI space${normal}"
set -e
if [ ! -s ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STD_IMAGE ) ]
then
  runname "    Calculating registeration matrix for MNI space"
  (
    register T1_BRAIN STD_IMAGE
    mv ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T1_BRAIN STD_IMAGE ) ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STD_IMAGE )
    inverse_transform PROC STD_IMAGE
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    set +e
    rm -f ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STD_IMAGE )  >/dev/null 2>&1
    echo_fatal "Unable calculating registeration matrix. Please try again."
  fi
fi

if [ "${NON_LINEAR}" = "YES" ]
then
  if [ ! -e "${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name PROC STD_IMAGE )" ]
  then
    runname "    Calculating nonlinear warp for MNI space"
    (
    set -e
    FNIRT_MASK=${SAFE_TMP_DIR}/$(basename ${HYP_MASK})

    if [ -s "$FLAIR_BRAIN" ]
    then
      ${FSLPREFIX}fslmaths $FLAIR_BRAIN -uthr $(${FSLPREFIX}fslstats $FLAIR_BRAIN -P 95) -mas ${T1_BRAIN} -bin $FNIRT_MASK
    fi
    if [ -s "$T2_BRAIN" ]
    then
      ${FSLPREFIX}fslmaths $T2_BRAIN -uthr $(${FSLPREFIX}fslstats $T2_BRAIN -P 95) -mas ${T1_BRAIN} -bin $FNIRT_MASK 
    fi

    FNIRT_OPTION="--in=${T1_BRAIN} --inmask=${FNIRT_MASK} --iout=$(std_image $T1_BRAIN)"
    FNIRT_OPTION="${FNIRT_OPTION} --aff=${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STD_IMAGE )"
    FNIRT_OPTION="${FNIRT_OPTION} --cout=${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name PROC STD_IMAGE )"
    ${FSLPREFIX}fnirt ${FNIRT_OPTION} --config=${CONFIG_ROOT}/T1_2_MNI152_2mm.conf
    )
    if [ $? -eq 0 ]
    then
      rundone 0
    else
      rundone 1
      rm -f ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STD_IMAGE )  >/dev/null 2>&1
      echo_fatal "Unable calculating registeration matrix. Please try again."
    fi
    rm -f ${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name STD_IMAGE PROC) >/dev/null 2>&1
  fi

  if [ ! -e "${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name STD_IMAGE PROC)" ]
  then
    runname "    Inverting warp"
    ${FSLPREFIX}invwarp --ref=${T1_BRAIN} --warp=${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name PROC STD_IMAGE ) --out=${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name STD_IMAGE PROC )
    if [ $? -eq 0 ]
    then
      rundone 0
    else
      rundone 1
      rm -f ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STD_IMAGE )  >/dev/null 2>&1
      echo_fatal "Unable invert. Please try again."
    fi

  fi

  runname "    Nonlinear warping neccesary images to standard MNI space"
  (
  WARP_CMD="${FSLPREFIX}applywarp --ref=$STD_IMAGE --warp=${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name PROC STD_IMAGE )"

  set +e
  ALL_IMAGES=$(ls ${IMAGEROOT}/${ranges_dir}/brain_{flair,t1,t2,pd}.nii.gz 2>/dev/null)
  set -e

  for img in $ALL_IMAGES
  do
    [ -s "$(std_image $img)" ] || $WARP_CMD --in=$img --out=$(std_image ${img})
  done

  if [ -s "$BRAIN_PVE" ] && [ ! -s "$(std_image ${BRAIN_PVE})" ]
  then
    $WARP_CMD --in=$BRAIN_PVE --out=$(std_image ${BRAIN_PVE}) --interp=nn
  fi
  if [ -s "$HYP_MASK" ] && [ ! -s "$(std_image ${HYP_MASK})" ]
  then
    $WARP_CMD --in=$HYP_MASK --out=$(std_image ${HYP_MASK}) --interp=nn
  fi

  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    set +e
    rm ${IMAGEROOT}/${std_dir}/*  >/dev/null 2>&1
    echo_fatal "Unable to process. Please try again."
  fi

  runname "    Nonlinear registering standard atlas to native"
  (
  WARP_CMD="${FSLPREFIX}applywarp --ref=$T1_BRAIN --warp=${IMAGEROOT}/${trans_dir}/$(nonlinear_trans_name STD_IMAGE PROC )"

  if [ ! -s "$ATLAS" ] && [ -e "$STD_ATLAS" ]
  then
    $WARP_CMD --in="$STD_ATLAS" --out="$ATLAS"
    ${FSLPREFIX}fslcpgeom $T1_BRAIN $ATLAS
  fi

  [ -s "${IMAGEROOT}/${images_dir}/std-white.nii.gz" ] || $WARP_CMD --in="$STANDARD_ROOT/white.nii.gz" --out="${IMAGEROOT}/${images_dir}/std-white.nii.gz"
  [ -s "${IMAGEROOT}/${images_dir}/std-gray.nii.gz" ] || $WARP_CMD --in="$STANDARD_ROOT/gray.nii.gz" --out="${IMAGEROOT}/${images_dir}/std-gray.nii.gz"
  [ -s "${IMAGEROOT}/${images_dir}/std-csf.nii.gz" ] || $WARP_CMD --in="$STANDARD_ROOT/csf.nii.gz" --out="${IMAGEROOT}/${images_dir}/std-csf.nii.gz"
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    set +e
    rm $ATLAS ${IMAGEROOT}/${images_dir}/std-*  >/dev/null 2>&1
    echo_fatal "Unable to process. Please try again."
  fi
else
### LINEAR
  runname "    Registering neccesary images to standard MNI space"
  (
  set +e
  ALL_IMAGES=$(ls ${IMAGEROOT}/${range_dir}/brain_{flair,t1,t2,pd}.nii.gz 2>/dev/null)
  set -e

  for img in $ALL_IMAGES
  do
    [ -s "$(std_image $img)" ] || register img STD_IMAGE - $(fsl_trans_name PROC STD_IMAGE ) $(std_image $img)  
  done

  
  if [ -s "$BRAIN_PVE" ] && [ ! -s "$(std_image ${BRAIN_PVE})" ]
  then
    FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS}  
    register BRAIN_PVE STD_IMAGE - $(fsl_trans_name PROC STD_IMAGE ) $(std_image ${BRAIN_PVE})
  fi
  if [ -s "$HYP_MASK" ] && [ ! -s "$(std_image ${HYP_MASK})" ]
  then
    FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS} 
    register HYP_MASK STD_IMAGE - $(fsl_trans_name PROC STD_IMAGE ) $(std_image ${HYP_MASK})
  fi

  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    set +e
    rm ${IMAGEROOT}/${std_dir}/*  >/dev/null 2>&1
    set -e
    echo_fatal "Unable to process. Please try again."
  fi
  
  runname "    Registering atlases and masks from MNI space"
  (
  set -e
  if [ ! -s "$ATLAS" ] && [ -e "$STD_ATLAS" ]
  then
    FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS}
    register STD_ATLAS T1_BRAIN - $(fsl_trans_name STD_IMAGE PROC ) $ATLAS
    ${FSLPREFIX}fslcpgeom $T1_BRAIN $ATLAS
  fi
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    rm -f $ATLAS ${IMAGEROOT}/${images_dir}/std-*  >/dev/null 2>&1
    echo_fatal "Unable to process. Please try again."
  fi
fi
