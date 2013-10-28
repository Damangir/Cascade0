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

   -t      T1 image
   -f      FLAIR image
   -p      PD image
   -s      T2 image

   -b      Brain mask
   -n      Brain mask space (T1, FLAIR, PD or T2)

   -a      Remove all pre-existing files
   -v      Verbose
   -l      Show licence
   
EOF
}

source $(dirname $0)/cascade-setup.sh
source $(dirname $0)/cascade-util.sh


IMAGEROOT=.
VERBOSE=
REMOVEALL="NO"
while getopts “hr:b:n:t:f:p:s:avl” OPTION
do
  case $OPTION in
## Subject directory
    r)
      IMAGEROOT=$OPTARG
      ;;
## Brain mask    
    b)
      INPUT_BRAIN_MASK=$(readlink -f $OPTARG)
      ;;
    n)
      BRAIN_MASK_SPACE=$(echo $OPTARG | tr '[:lower:]' '[:upper:]' )
      ;;
## Sequences      
    t)
      T1=$(readlink -f $OPTARG)
      ;;
    f)
      FLAIR=$(readlink -f $OPTARG)
      ;;
    p)
      PD=$(readlink -f $OPTARG)
      ;;
    s)
      T2=$(readlink -f $OPTARG)
      ;;
## Running behaviours        
    a)
      REMOVEALL="YES"
      ;;
    v)
      VERBOSE=1
      ;;
## Help and licence      
    l)
      copyright
      licence
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

copyright
if [ $# == 0 ]
then
    usage
    exit 1
fi

# TODO: Check for allowed combination and produce readable error.
if [ ! -f $T1 ]
then
  echo_fatal "T1 image not found."
fi
if [ ! -f $T2 ] && [ ! -f $FLAIR ]
then
  echo_fatal "Either FLAIR or T2 should be available."
fi
if [ -f $T2 ] && [ -f $FLAIR ]
then
  echo_warning "It is not advised to use both T2 and FLAIR."
fi
if [ $BRAIN_MASK_SPACE != "NONE" ]
then
  if [ ! -f "$INPUT_BRAIN_MASK" ]
  then
    echo_fatal "No input brain mask. Hint! If the images are already brain extracted use -n NONE."
  fi
  if [ $BRAIN_MASK_SPACE != "T1" ] && [ $BRAIN_MASK_SPACE != "T2" ] && [ $BRAIN_MASK_SPACE != "PD" ] && [ $BRAIN_MASK_SPACE != "FLAIR" ]
  then
    echo_fatal "Invalid space for brain mask. T1, T2, FLAIR, PD or NONE is allowed." 
  fi
fi


IMAGEROOT=$(readlink -f $IMAGEROOT)     
echo "Preprocessing subject at: ${IMAGEROOT}"

check_fsl
check_cascade
set_filenames

rm -rf ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir}}
mkdir -p ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir}}

runname "Calculating registeration matrix"
(
set -e
if [ "$FLAIR" ]
then
  do_register T1 FLAIR
  do_register T2 FLAIR
  do_register PD FLAIR
else
  do_register T1 T2
  do_register FLAIR T2
  do_register PD T2
fi
)
rundone $?

runname "Masking brain"
(
set -e


if [ "$BRAIN_MASK_SPACE" = "NONE" ]
then
  INPUT_BRAIN_MASK=${IMAGEROOT}/${temp_dir}/extracted_brain_mask.nii.gz
  BRAIN_MASK_SPACE="T1"
  fslmaths $T1 -bin $INPUT_BRAIN_MASK 
fi

if [  $FLAIR ]
then
  if [ $BRAIN_MASK_SPACE == "T1" ]; then
    register INPUT_BRAIN_MASK FLAIR - $(fsl_trans_name T1 FLAIR ) $BRAIN_MASK
  elif [ $BRAIN_MASK_SPACE == "T2" ]; then
    register INPUT_BRAIN_MASK FLAIR - $(fsl_trans_name T2 FLAIR ) $BRAIN_MASK
  elif [ $BRAIN_MASK_SPACE == "FLAIR" ]; then
    cp $INPUT_BRAIN_MASK $BRAIN_MASK
  elif [ $BRAIN_MASK_SPACE == "PD" ]; then
	  register INPUT_BRAIN_MASK FLAIR - $(fsl_trans_name PD FLAIR ) $BRAIN_MASK
	fi
else
  if [ $BRAIN_MASK_SPACE == "T1" ]; then
    register INPUT_BRAIN_MASK T2 - $(fsl_trans_name T1 T2 ) $BRAIN_MASK
  elif [ $BRAIN_MASK_SPACE == "FLAIR" ]; then
    register INPUT_BRAIN_MASK T2 - $(fsl_trans_name FLAIR T2 ) $BRAIN_MASK
  elif [ $BRAIN_MASK_SPACE == "T2" ]; then
    cp $INPUT_BRAIN_MASK $BRAIN_MASK
  elif [ $BRAIN_MASK_SPACE == "PD" ]; then
    register INPUT_BRAIN_MASK T2 - $(fsl_trans_name PD T2 ) $BRAIN_MASK
  fi
fi

[ $T1 ] && mask T1 BRAIN_MASK T1_BRAIN
[ $T2 ] && mask T2 BRAIN_MASK T2_BRAIN
[ $FLAIR ] && mask FLAIR BRAIN_MASK FLAIR_BRAIN
[ $PD ] && mask PD BRAIN_MASK PD_BRAIN
)
rundone $?

runname "Registering normal brain"
(
set -e
if [ ! -s ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T1 STDIMAGE ) ]
then
  register T1_BRAIN STDIMAGE
  mv ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T1_BRAIN STDIMAGE ) ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T1 STDIMAGE )
fi

if [ ! -s ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STDIMAGE ) ]
then
  if [ $FLAIR ]
  then
    concat_transform FLAIR T1 STDIMAGE
    mv ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name FLAIR STDIMAGE ) ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STDIMAGE )
  else
    concat_transform T2 T1 STDIMAGE
    mv ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T2 STDIMAGE ) ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STDIMAGE )
  fi
  inverse_transform PROC STDIMAGE
fi
if [ ! -s $PROC_ATLAS ]
then
  FLIRT_OPTION=${FLAIR_OPTIONS_FOR_ATLAS}
  register STDATLAS FLAIR - $(fsl_trans_name STDIMAGE PROC ) $PROC_ATLAS
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