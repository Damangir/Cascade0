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
  echo_fatal "IMAGEROOT \"${IMAGEROOT}\" is not a directory."
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
      set +e
      rm -rf ${BRAIN_CSF} ${BRAIN_GM} ${BRAIN_WM}
    )
    if [ $? -eq 0 ]
    then
      rundone 0
    else
      rundone 1
      set +e
      rm -rf ${BRAIN_CSF} ${BRAIN_GM} ${BRAIN_WM} ${IMAGEROOT}/${temp_dir}/brain* >/dev/null 2>&1
      echo_fatal "Unable to process. Please try again."
    fi
    break
  fi
done

runname "Refining brain segmentation"
(
set -e
if [ "$BASH_SOURCE" -nt "$BRAIN_PV" ]
then
  POS_WM=${SAFE_TMP_DIR}/possible_wm.nii.gz

  ${FSLPREFIX}fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_0.nii.gz -nan -thr 0.5 -bin ${BRAIN_CSF}
  ${FSLPREFIX}fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_1.nii.gz -nan -thr 0.5 -bin ${BRAIN_GM}
  ${FSLPREFIX}fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_2.nii.gz -nan -thr 0.5 -bin ${BRAIN_WM}
  ${FSLPREFIX}fslmaths ${BRAIN_WM} -mul 0 "$POS_WM"

# TODO: Maybe small CSF can be a candidate
       
  if [ -s "$FLAIR_BRAIN" ]
  then
    _perc=($(${FSLPREFIX}fslstats $FLAIR_BRAIN -k ${BRAIN_GM} -p 16 -p 84))
    flair_thresh=$( bc -l <<< "${_perc[1]} + 0.5 * (${_perc[1]}-${_perc[0]})" )
    ${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr $flair_thresh -add "$POS_WM" -bin "$POS_WM"
  fi

  if [ -s "$T2_BRAIN" ]
  then
    _perc=($(${FSLPREFIX}fslstats $T2_BRAIN -k ${BRAIN_GM} -p 16 -p 84))
    t2_thresh=$( bc -l <<< "${_perc[1]} + 0.5 * (${_perc[1]}-${_perc[0]})" )
    ${FSLPREFIX}fslmaths $T2_BRAIN -thr $t2_thresh -add "$POS_WM" -bin "$POS_WM"
  fi

	if [ -s "${IMAGEROOT}/${images_dir}/std-white.nii.gz" ]
  then
    ${FSLPREFIX}fslmaths "$POS_WM" -mul ${IMAGEROOT}/${images_dir}/std-white.nii.gz -thr 0.35 -bin  "$POS_WM"
  fi
  
# TODO: IF a POS_WM segment is sorounded by GM or CSF then it is probably actually a GM

  ${FSLPREFIX}fslmaths ${BRAIN_CSF} -mul -1 -add 1 -mul "$POS_WM" -bin "$POS_WM"
  
  ${FSLPREFIX}fslmaths ${BRAIN_WM} -mul -1 -add 1 -mul "$POS_WM" ${IMAGEROOT}/${images_dir}/possible_wm

  ${FSLPREFIX}fslmaths ${BRAIN_WM} -add "$POS_WM" -bin ${BRAIN_WM}

  ${FSLPREFIX}fslmaths ${BRAIN_WM} -mul -1 -add 1 -mul ${BRAIN_CSF} -bin ${BRAIN_CSF}    
  ${FSLPREFIX}fslmaths ${BRAIN_WM} -mul -1 -add 1 -mul ${BRAIN_GM} -bin -mul 2 ${BRAIN_GM}
  ${FSLPREFIX}fslmaths ${BRAIN_WM} -bin -mul 3 ${BRAIN_WM}
  
  ${FSLPREFIX}fslmaths ${BRAIN_GM} -add ${BRAIN_WM} -bin ${BRAIN_WMGM}
  ${FSLPREFIX}fslmaths ${BRAIN_CSF} -add ${BRAIN_GM} -add ${BRAIN_WM} ${BRAIN_PVE}

  cp $POS_WM ${IMAGEROOT}/${images_dir}
fi
)
if [ $? -eq 0 ]
then
  rundone 0
else
  rundone 1
  set +e
  rm -rf ${BRAIN_CSF} ${BRAIN_GM} ${BRAIN_WM} ${BRAIN_PVE} ${BRAIN_WMGM} >/dev/null 2>&1
  echo_fatal "Unable to process. Please try again."
fi
