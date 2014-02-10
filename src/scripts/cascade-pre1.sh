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
   -l      Show license
   
EOF
}

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh

IMAGEROOT=.
VERBOSE=
REMOVEALL="NO"
# TODO: Infere from parameters.
REGISTERED="NO"
while getopts “hr:b:n:t:f:p:s:avl” OPTION
do
  case $OPTION in
## Subject directory
    r)
      IMAGEROOT=$OPTARG
      ;;
## Brain mask    
    b)
      INPUT_BRAIN_MASK="$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")"
      ;;
    n)
      BRAIN_MASK_SPACE=$(echo $OPTARG | tr '[:lower:]' '[:upper:]' )
      ;;
## Sequences      
    t)
      T1="$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")"
      ;;
    f)
      FLAIR="$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")"
      ;;
    p)
      PD="$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")"
      ;;
    s)
      T2="$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")"
      ;;
## Running behaviours        
    a)
      REMOVEALL="YES"
      ;;
    v)
      VERBOSE=1
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

cascade_copyright
if [ $# == 0 ]
then
    usage
    exit 1
fi

# TODO: Check for allowed combination and produce readable error.
if [ ! -f "$T1" ]
then
  echo_fatal "T1 image not found."
fi
if [ ! -f "$T2" ] && [ ! -f "$FLAIR" ]
then
  echo_fatal "Either FLAIR or T2 should be available."
fi
if [ -f "$T2" ] && [ -f "$FLAIR" ]
then
  echo_warning "It is not advised to use both T2 and FLAIR."
fi
if [ "$BRAIN_MASK_SPACE" != "NONE" ]
then
  if [ ! -f "$INPUT_BRAIN_MASK" ]
  then
    echo_fatal "No input brain mask. Hint! If the images are already brain extracted use -n NONE."
  fi
  if [ "$BRAIN_MASK_SPACE" != "T1" ] && [ "$BRAIN_MASK_SPACE" != "T2" ] && [ "$BRAIN_MASK_SPACE" != "PD" ] && [ "$BRAIN_MASK_SPACE" != "FLAIR" ]
  then
    echo_fatal "Invalid space for brain mask. T1, T2, FLAIR, PD or NONE is allowed." 
  fi
fi
# By here, we are sure that T1 image is there and also either FLAIR and T2 is
# available

IMAGEROOT=$(cd "$IMAGEROOT" && pwd -P )
echo "${bold}The Cascade Pre-processing step 1${normal}"
set_filenames
[ $REMOVEALL == "YES" ] && rm -rf ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir}}
mkdir -p ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir},${std_dir}}

runname "Calculating registeration matrix"

# TODO: REG_ should be saved somewhere.
set -e
if [ -s "$FLAIR" ]
then
  REG_T1=$(do_register T1 FLAIR)
  REG_T2=$(do_register T2 FLAIR)
  REG_PD=$(do_register PD FLAIR)
  REG_FLAIR=$FLAIR
else
  REG_T1=$(do_register T1 T2)
  REG_T2=$T2
  REG_PD=$(do_register PD T2)
  REG_FLAIR=$(do_register FLAIR T2)
fi
# By here we are sure that all images $REG_ are present and in the common space
# of either FLAIR or T2
rundone $?

runname "Masking brain"
(
set -e
if [ "$BRAIN_MASK_SPACE" = "NONE" ]
then
  INPUT_BRAIN_MASK=${IMAGEROOT}/${temp_dir}/extracted_brain_mask.nii.gz
  BRAIN_MASK_SPACE="T1"
  ${FSLPREFIX}fslmaths $T1 -bin $INPUT_BRAIN_MASK 
fi
if  [ ! -s $BRAIN_MASK ]
then
  FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS}
  if [  "$FLAIR" ]
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
fi

[ "$REG_T1" ] && [ ! -s "$T1_BRAIN" ] && mask REG_T1 BRAIN_MASK T1_BRAIN
[ "$REG_T2" ] && [ ! -s "$T2_BRAIN" ] && mask REG_T2 BRAIN_MASK T2_BRAIN
[ "$REG_FLAIR" ] && [ ! -s "$FLAIR_BRAIN" ] && mask REG_FLAIR BRAIN_MASK FLAIR_BRAIN
[ "$REG_PD" ] && [ ! -s "$PD_BRAIN" ] && mask REG_PD BRAIN_MASK PD_BRAIN
true
)
# By here $BRAIN_MASK and brain images are created _BRAIN
rundone $?

runname "Calculating registeration matrix for MNI space"
(
set -e
# By here, T1 and FLAIR are in the same space
if [ ! -s ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STD_IMAGE ) ]
then
  register T1_BRAIN STD_IMAGE
  mv ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name T1_BRAIN STD_IMAGE ) ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STD_IMAGE )
  inverse_transform PROC STD_IMAGE
fi
)
rundone $?

runname "Registering atlases and masks from MNI space"
(
set -e
if [ ! -s "$ATLAS" ] && [ -e "$STD_ATLAS" ]
then
  FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS}
  register STD_ATLAS T1_BRAIN - $(fsl_trans_name STD_IMAGE PROC ) $ATLAS
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $ATLAS
fi
if [ ! -s "$MIDDLE" ]
then
  FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS}
  register STD_MIDDLE T1_BRAIN - $(fsl_trans_name STD_IMAGE PROC ) $MIDDLE
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $MIDDLE
fi
if [ ! -s "$OUTER_10" ]
then
  FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS}
  register STD_OUTER_10 T1_BRAIN - $(fsl_trans_name STD_IMAGE PROC ) $OUTER_10
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $OUTER_10
fi
if [ ! -s "$MIDDLE_10" ]
then
  FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS}
  register STD_MIDDLE_10 T1_BRAIN - $(fsl_trans_name STD_IMAGE PROC ) $MIDDLE_10
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $MIDDLE_10
fi
if [ ! -s "$OUTER_20" ]
then
  FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS}
  register STD_OUTER_20 T1_BRAIN - $(fsl_trans_name STD_IMAGE PROC ) $OUTER_20
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $OUTER_20
fi
if [ ! -s "$MIDDLE_20" ]
then
  FLIRT_OPTION=${FLIRT_OPTIONS_FOR_ATLAS}
  register STD_MIDDLE_20 T1_BRAIN - $(fsl_trans_name STD_IMAGE PROC ) $MIDDLE_20
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $MIDDLE_20
fi
)
rundone $?

#TODO: Tune it brain mask check!
if []; then
  
runname "Checking brain mask"
${FSLPREFIX}fslmaths $MIDDLE -mul 2 -add $BRAIN_MASK ${IMAGEROOT}/${temp_dir}/std_vs_mask.nii.gz
dets=($(${FSLPREFIX}fslstats ${IMAGEROOT}/${temp_dir}/std_vs_mask.nii.gz -l 0 -H 3 1 3))
rundone $?
if [ "$(bc -l <<<"(${dets[0]} + ${dets[1]}) / ${dets[2]} < 0.5")" -eq "1" ]
then
  echo_warning "Brain mask seems odd. Please QC the brain mask."
fi
if [ "$(bc -l <<<"(${dets[0]} + ${dets[1]}) / ${dets[2]} < 0.8")" -eq "1" ]
then
  echo_warning "Brain mask seems odd. Will be replaced with the brain mask from standard atlas"
  runname "Re-masking brain"
  (
    set +e
	  [ "$REG_T1" ]  && mask REG_T1 MIDDLE T1_BRAIN
		[ "$REG_T2" ]  && mask REG_T2 MIDDLE T2_BRAIN
		[ "$REG_FLAIR" ] && mask REG_FLAIR MIDDLE FLAIR_BRAIN
		[ "$REG_PD" ]  && mask REG_PD MIDDLE PD_BRAIN
		true
	)
  rundone $?
fi

fi

set -e
$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-tissue-type.sh -r $IMAGEROOT
$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-histogram.sh -r $IMAGEROOT
set +e