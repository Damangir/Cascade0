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
REGISTERED="YES"
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

[ $REMOVEALL == "YES" ] && rm -rf ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir}}

mkdir -p ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir},${std_dir}}

runname "Calculating registeration matrix"
(
set -e
if [ -s "$FLAIR" ]
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
  ${FSLPREFIX}fslmaths $T1 -bin $INPUT_BRAIN_MASK 
fi
if  [ ! -s $BRAIN_MASK ]
then
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
fi

[ $T1 ] && [ ! -s $T1_BRAIN ] && mask T1 BRAIN_MASK T1_BRAIN
[ $T2 ] && [ ! -s $T2_BRAIN ] && mask T2 BRAIN_MASK T2_BRAIN
[ $FLAIR ] && [ ! -s $FLAIR_BRAIN ] && mask FLAIR BRAIN_MASK FLAIR_BRAIN
[ $PD ] && [ ! -s $PD_BRAIN ] && mask PD BRAIN_MASK PD_BRAIN

true
)
rundone $?

runname "Calculating registeration matrix for MNI space"
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
)
rundone $?

runname "Registering atlases and masks from MNI space"
(
set -e
if [ ! -s $ATLAS ]
then
  FLIRT_OPTION=${FLAIR_OPTIONS_FOR_ATLAS}
  register STD_ATLAS FLAIR - $(fsl_trans_name STDIMAGE PROC ) $ATLAS
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $ATLAS
fi
if [ ! -s $MIDDLE ]
then
  FLIRT_OPTION=${FLAIR_OPTIONS_FOR_ATLAS}
  register STD_MIDDLE FLAIR - $(fsl_trans_name STDIMAGE PROC ) $MIDDLE
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $MIDDLE
fi
if [ ! -s $OUTER_10 ]
then
  FLIRT_OPTION=${FLAIR_OPTIONS_FOR_ATLAS}
  register STD_OUTER_10 FLAIR - $(fsl_trans_name STDIMAGE PROC ) $OUTER_10
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $OUTER_10
fi
if [ ! -s $MIDDLE_10 ]
then
  FLIRT_OPTION=${FLAIR_OPTIONS_FOR_ATLAS}
  register STD_MIDDLE_10 FLAIR - $(fsl_trans_name STDIMAGE PROC ) $MIDDLE_10
  ${FSLPREFIX}fslcpgeom $T1_BRAIN $MIDDLE_10
fi
)
rundone $?

set -e
$(dirname $0)/cascade-tissue-type.sh -r $IMAGEROOT
set +e

set -e
$(dirname $0)/cascade-histogram.sh -r $IMAGEROOT
set +e