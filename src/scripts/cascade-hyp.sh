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

for pve_ in $(echo ${IMAGEROOT}/${temp_dir}/brain_pve_{0,1,2}.nii.gz )
do
  if [ ! -s "${pve_}" ]
  then
runname "Segmenting brain tissues"
(
    set -e
    ${FSLPREFIX}fast -t 1 -o ${IMAGEROOT}/${temp_dir}/brain -n 3 ${T1_BRAIN}
    rm -rf ${BRAIN_CSF} ${BRAIN_GM} ${BRAIN_WM}
)
rundone $?
    break
  fi
done


echo "${bold}Calculating heuristics${normal}"

${FSLPREFIX}fslmaths ${T1_BRAIN} -bin $HYP_MASK


WM_IMAGE=${IMAGEROOT}/${temp_dir}/brain_pve_2.nii.gz
GM_IMAGE=${IMAGEROOT}/${temp_dir}/brain_pve_1.nii.gz

# If we already refined the brain tissue we can have a better guess
[ -s "${BRAIN_WM}" ] && WM_IMAGE=${BRAIN_WM}
[ -s "${BRAIN_GM}" ] && GM_IMAGE=${BRAIN_GM}

if [ -s "$FLAIR_BRAIN" ]
then
  runname "    Heuristic: Should be light FLAIR"
  (
    set -e
    flair_thresh=$(${FSLPREFIX}fslstats $FLAIR_BRAIN -k ${WM_IMAGE} -P 80)
    ${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr $flair_thresh -add ${GM_IMAGE} -mul $HYP_MASK -bin $HYP_MASK
    flair_thresh=$(${FSLPREFIX}fslstats $FLAIR_BRAIN -k ${GM_IMAGE} -P 90)
    ${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr $flair_thresh -add ${WM_IMAGE} -mul $HYP_MASK -bin $HYP_MASK
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    rm "$HYP_MASK"  >/dev/null 2>&1
    echo_fatal "Unable to process. Please try again."
  fi
fi

if [ -s "$T2_BRAIN" ]
then
  runname "    Heuristic: Should be light T2"
  (
    set -e
    t2_thresh=$(${FSLPREFIX}fslstats $T2_BRAIN -k ${WM_IMAGE} -P 80)
    ${FSLPREFIX}fslmaths $T2_BRAIN -thr $t2_thresh -add ${GM_IMAGE} -mul $HYP_MASK -bin $HYP_MASK
    t2_thresh=$(${FSLPREFIX}fslstats $T2_BRAIN -k ${GM_IMAGE} -P 90)
    ${FSLPREFIX}fslmaths $T2_BRAIN -thr $t2_thresh -add ${WM_IMAGE} -mul $HYP_MASK -bin $HYP_MASK
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    rm "$HYP_MASK"  >/dev/null 2>&1
    echo_fatal "Unable to process. Please try again."
  fi
fi

if [ -s "$T1_BRAIN" ]
then
  runname "    Heuristic: Not bright on T1"
  (
    set -e
    t1_thresh=$(${FSLPREFIX}fslstats $T1_BRAIN -k ${WM_IMAGE} -P 80)
    ${FSLPREFIX}fslmaths $T1_BRAIN -uthr $t1_thresh -bin -mul $HYP_MASK -bin $HYP_MASK
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    rm "$HYP_MASK"  >/dev/null 2>&1
    echo_fatal "Unable to process. Please try again."
  fi
fi

if [ -s "${BRAIN_WM}" ]
then
  runname "    Heuristic: Either WM or in the WM-GM boundary"
  (
    set -e
    ${FSLPREFIX}fslmaths ${BRAIN_WM} -bin -kernel sphere 1 -dilF ${SAFE_TMP_DIR}/enlarged-wm.nii.gz
    ${FSLPREFIX}fslmaths ${SAFE_TMP_DIR}/enlarged-wm.nii.gz -mul $HYP_MASK -bin $HYP_MASK
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    rm "$HYP_MASK"  >/dev/null 2>&1
    echo_fatal "Unable to process. Please try again."
  fi
fi

if [ -s "${BRAIN_CSF}" ] 
then
  runname "    Heuristic: Either Not in CSF"
  (
    set -e
    ${FSLPREFIX}fslmaths ${BRAIN_CSF} -bin -mul -1 -add 1 -mul $HYP_MASK -bin $HYP_MASK
  )
  if [ $? -eq 0 ]
  then
    rundone 0
  else
    rundone 1
    rm "$HYP_MASK"  >/dev/null 2>&1
    echo_fatal "Unable to process. Please try again."
  fi
fi


