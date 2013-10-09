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
   -b      Brain mask on T1
   -t      T1 image
   -f      FLAIR image
   -a      Run all the steps, do not use cache
   -v      Verbose
   -l      Show licence
   
EOF
}

source $(dirname $0)/cascade-setup.sh
source $(dirname $0)/cascade-util.sh


IMAGEROOT=.
VERBOSE=
FOURCERUN=1
while getopts “hr:b:t:f:val” OPTION
do
  case $OPTION in
		h)
		  usage
      exit 1
      ;;
    r)
      IMAGEROOT=$OPTARG
      ;;
    b)
      T1_BRAIN_MASK=`readlink -f $OPTARG`
      ;;
    t)
      T1=`readlink -f $OPTARG`
      ;;
    f)
      FLAIR=`readlink -f $OPTARG`
      ;;
    a)
      FOURCERUN=
      ;;
    v)
      VERBOSE=1
      ;;
    l)
      copyright
      licence
      exit 1
      ;;    
    ?)
      usage
      exit
      ;;
  esac
done

copyright
if [ $# == 0 ]
then
    usage
    exit 1
fi

if [ ! $T1 ]
then
  echo_fatal "T1 image not found."
fi

IMAGEROOT=$(readlink -f $IMAGEROOT)     
echo "Preprocessing subject at: ${IMAGEROOT}"
mkdir -p ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir}}

check_fsl
check_cascade

set_filenames


runname "Calculating registeration matrix"
(
set -e
if [ ! -s ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T1 FLAIR ) ]
then
  register FLAIR T1
  inverse_transform FLAIR T1
fi
)
rundone $?
runname "Registering and masking T1"
(
set -e
if [ ! -s ${IMAGEROOT}/${images_dir}/brain_t1.nii.gz ]
then
  mask T1 T1_BRAIN_MASK T1_BRAIN_TMP
  register T1_BRAIN_TMP FLAIR - $(fsl_trans_name T1 FLAIR ) $T1_BRAIN
fi
if [ ! -s ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T1 STDIMAGE ) ]
then
  register T1_BRAIN_TMP STDIMAGE
  mv ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T1_BRAIN_TMP STDIMAGE ) ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T1 STDIMAGE )
fi
if [ ! -s ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STDIMAGE ) ]
then
  concat_transform FLAIR T1 STDIMAGE
  mv ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name FLAIR STDIMAGE ) ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STDIMAGE )
  inverse_transform PROC STDIMAGE
  FLIRT_OPTION=${FLAIR_OPTIONS_FOR_ATLAS}
  register STDATLAS FLAIR - $(fsl_trans_name STDIMAGE PROC ) $PROC_ATLAS
fi
)
rundone $?

runname "Registering and masking FLAIR"
(
set -e
if [ ! -s ${FLAIR_BRAIN} ]
then
  FLIRT_OPTION=${FLAIR_OPTIONS_FOR_ATLAS}
  register T1_BRAIN_MASK FLAIR ${temp_dir} $(fsl_trans_name T1 FLAIR ) 
  mask FLAIR BRAIN_MASK FLAIR_BRAIN 
fi
)
rundone $?

runname "Segmenting brain tissues"
(
set -e
if [ ! -s ${IMAGEROOT}/${temp_dir}/brain_pveseg.nii.gz ]
then
  fast -t 1 -o ${IMAGEROOT}/${temp_dir}/brain -n 3 ${T1_BRAIN}
fi

if [ ! -s ${BRAIN_CSF} ]
then
  fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_1.nii.gz -nan -thr 0.5 -bin ${IMAGEROOT}/${temp_dir}/brain_puregm.nii.gz
  $CASCADEDIR/cascade-property-filter -i ${IMAGEROOT}/${temp_dir}/brain_puregm.nii.gz -o ${IMAGEROOT}/${temp_dir}/brain_false_puregm.nii.gz --property PhysicalSize --threshold 1000 -r     
  
  fslmaths ${IMAGEROOT}/${temp_dir}/brain_false_puregm.nii.gz -kernel 3D -dilM ${IMAGEROOT}/${temp_dir}/brain_false_puregm.nii.gz
  fslmaths ${IMAGEROOT}/${temp_dir}/brain_false_puregm.nii.gz -bin -mul ${IMAGEROOT}/${temp_dir}/brain_pve_1.nii.gz -add ${IMAGEROOT}/${temp_dir}/brain_pve_2.nii.gz ${IMAGEROOT}/${temp_dir}/brain_pve_mod_2.nii.gz   
  fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_1.nii.gz -sub ${IMAGEROOT}/${temp_dir}/brain_false_puregm.nii.gz -thr 0 ${IMAGEROOT}/${temp_dir}/brain_pve_mod_1.nii.gz   
    
  fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_mod_2.nii.gz -thr 0.5 -bin ${BRAIN_WM}
  fslmaths ${BRAIN_WM} -mul -1 -add 1 ${IMAGEROOT}/${temp_dir}/brain_wm_holes.nii.gz 
  $CASCADEDIR/cascade-property-filter -i ${IMAGEROOT}/${temp_dir}/brain_wm_holes.nii.gz -o ${IMAGEROOT}/${temp_dir}/brain_wm_holes.nii.gz --property PhysicalSize --threshold 300 --reverse
  
  fslmaths ${BRAIN_WM} -add ${IMAGEROOT}/${temp_dir}/brain_wm_holes.nii.gz ${BRAIN_WM} 
  
  fslmaths ${IMAGEROOT}/${temp_dir}/brain_pve_mod_1.nii.gz -thr 0.5 -bin ${BRAIN_GM}
  fslmaths ${BRAIN_WM} -mul -1 -add 1 -mul ${BRAIN_GM} -bin ${BRAIN_GM}
  
  fslmaths ${IMAGEROOT}/${temp_dir}/brain_pveseg.nii.gz -thr 1 -uthr 1 ${BRAIN_CSF}
fi

if [ ! -s ${BRAIN_PVE} ]
then
  fslmaths ${BRAIN_CSF} -bin -mul 1 ${BRAIN_CSF}
  fslmaths ${BRAIN_GM} -bin -mul 2 ${BRAIN_GM}
  fslmaths ${BRAIN_WM} -bin -mul 3 ${BRAIN_WM}
  fslmaths ${BRAIN_CSF} -add ${BRAIN_GM} -add ${BRAIN_WM} ${BRAIN_PVE}
fi

if [ ! -s ${BRAIN_THIN_GM} ]
then
  fslmaths ${BRAIN_WM} -add ${BRAIN_GM} -bin ${BRAIN_WMGM}
fslmaths ${BRAIN_WMGM} -bin -mul -1 -add 1 -kernel sphere 2 -dilM -dilM -mas ${BRAIN_GM} ${BRAIN_THIN_GM}
fi 

)
rundone $?

runname "Normalizing input images"
(
set -e

ALL_IMAGES=$(ls ${IMAGEROOT}/${images_dir}/brain_*.nii.gz | grep -v pve| grep -v mixel )
for img in $ALL_IMAGES
do
  ranged_img=$(range_image $img)
  if [ ! -s $ranged_img ]
  then
    $CASCADEDIR/cascade-range --input ${img} --mask ${BRAIN_WMGM} --out ${ranged_img}
  fi
done
)
rundone $?

echo "Preprocessing done successfully for subject at: ${IMAGEROOT}"