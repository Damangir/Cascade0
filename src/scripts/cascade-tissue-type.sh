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
  echo_fatal "IMAGEROOT \"${IMAGEROOT}\" is not a directory."
fi

set_filenames

mkdir -p ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir}}

runname "Segmenting brain tissues"
(
set -e
for pve_ in $(echo ${IMAGEROOT}/${temp_dir}/brain_pve_{0,1,2}.nii.gz )
do
  if [ ! -s "${pve_}" ]
  then
    ${FSLPREFIX}fast -t 1 -o ${IMAGEROOT}/${temp_dir}/brain -n 3 ${T1_BRAIN}
    rm -rf ${BRAIN_CSF} ${BRAIN_GM} ${BRAIN_WM}
    break
  fi
done
)
rundone $?

runname "Refining brain segmentation"
(
set -e
#if true
if [ ! -s ${BRAIN_WM} ]
then
  ${FSLPREFIX}fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_0.nii.gz -nan -thr 0.5 -bin ${BRAIN_CSF}
  ${FSLPREFIX}fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_1.nii.gz -nan -thr 0.5 -bin ${BRAIN_GM}
  ${FSLPREFIX}fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_2.nii.gz -nan -thr 0.5 -bin ${BRAIN_WM}
      
	if [ -s $FLAIR_BRAIN ]
	then  
	  PERCENTILE=($(fsl5.0-fslstats $FLAIR_BRAIN -k ${BRAIN_WM} -P 50 -P 60 -P 70 -P 80 -P 90 -P 95 -P 99))

${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr ${PERCENTILE[3]} -bin ${SAFE_TMP_DIR}/est_wml_80_flair.nii.gz
${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr ${PERCENTILE[4]} -bin ${SAFE_TMP_DIR}/est_wml_90_flair.nii.gz
${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr ${PERCENTILE[5]} -bin ${SAFE_TMP_DIR}/est_wml_95_flair.nii.gz
${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr ${PERCENTILE[6]} -bin ${SAFE_TMP_DIR}/est_wml_99_flair.nii.gz

    # TODO: A better way to identify cortex
    # If a CSF is bright in FLAIR, it might be misclassified WML.
    ${FSLPREFIX}fslmaths ${SAFE_TMP_DIR}/est_wml_95_flair.nii.gz -mas $OUTER_20 -mul -1 -add 1 -mul ${BRAIN_CSF} -bin ${BRAIN_CSF}
    ${FSLPREFIX}fslmaths ${SAFE_TMP_DIR}/est_wml_90_flair.nii.gz -mas $MIDDLE_20 -mul -1 -add 1 -mul ${BRAIN_CSF} -bin ${BRAIN_CSF}
    
    # If a GM is bright in FLAIR, it might be misclassified WML.
    ${FSLPREFIX}fslmaths ${SAFE_TMP_DIR}/est_wml_99_flair.nii.gz -mas $OUTER_20 -mul -1 -add 1 -mul ${BRAIN_GM} -bin ${BRAIN_GM}
    ${FSLPREFIX}fslmaths ${SAFE_TMP_DIR}/est_wml_95_flair.nii.gz -mas $MIDDLE_20 -mul -1 -add 1 -mul ${BRAIN_GM} -bin ${BRAIN_GM}
    
    $CASCADEDIR/cascade-property-filter -i ${BRAIN_GM} -o ${BRAIN_GM} --property PhysicalSize --threshold 1000
    ${FSLPREFIX}fslcpgeom ${BRAIN_MASK} ${BRAIN_GM}
    
    ${FSLPREFIX}fslmaths $BRAIN_MASK -bin -sub ${BRAIN_GM} -sub ${BRAIN_CSF} ${BRAIN_WM}
   fi
   rm -rf ${BRAIN_PVE}
fi

if [ ! -s ${BRAIN_PVE} ]
then
  ${FSLPREFIX}fslmaths ${BRAIN_CSF} -bin -mul 1 ${BRAIN_CSF}
  ${FSLPREFIX}fslmaths ${BRAIN_GM} -bin -mul 2 ${BRAIN_GM}
  ${FSLPREFIX}fslmaths ${BRAIN_WM} -bin -mul 3 ${BRAIN_WM}
  ${FSLPREFIX}fslmaths ${BRAIN_CSF} -add ${BRAIN_GM} -add ${BRAIN_WM} ${BRAIN_PVE}
fi
if [ ! -s ${BRAIN_WMGM} ]
then
  ${FSLPREFIX}fslmaths ${BRAIN_GM} -add ${BRAIN_WM} -bin ${BRAIN_WMGM}
fi

)
rundone $?

