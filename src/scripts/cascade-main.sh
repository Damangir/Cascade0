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

This script runs the main procedure of the Cascade pipeline

${bold}OPTIONS$normal:
General:
   -r      Image root directory
   -s      State image
Training mode:   
   -m      WML mask
   -n      Updated state image
Misc.:
   -h      Show this message
   -f      Fource run all steps
   -v      Verbose
   -l      Show licence
EOF
}

source $(dirname $0)/cascade-setup.sh
source $(dirname $0)/cascade-util.sh

IMAGEROOT=.
VERBOSE=
FOURCERUN=1
MODE="MEASURE"
while getopts “hr:s:m:n:vfl” OPTION
do
  case $OPTION in
		h)
		  usage
      exit 1
      ;;
    r)
      IMAGEROOT=`readlink -f $OPTARG`
      ;;
    n)
      NEWSTATEIMAGE=`readlink -f $OPTARG`
      MODE="TRAIN"
      ;;
    m)
      MASKIMAGE=`readlink -f $OPTARG`
      MODE="TRAIN"
      ;;
    s)
      STATEIMAGE=`readlink -f $OPTARG`
      ;;
    f)
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

if [ $MODE == "MEASURE" ]
then
  echo "${bold}Running the Cascade in measurement mode.${normal}"
  [ $STATEIMAGE ] || echo_fatal "State file not set."
else
  echo "${bold}Running the Cascade in training mode.${normal}"
  [ $NEWSTATEIMAGE ] || echo_fatal "New state file not set."
  [ -d $(dirname $NEWSTATEIMAGE) ] || echo_fatal "Can not write to the folder: $(dirname $NEWSTATEIMAGE)"
  [ $MASKIMAGE ] || echo_warning "Mask file not set. Training will perform assuming most of the brain is healthy."
fi

IMAGEROOT=$(readlink -f $IMAGEROOT)
SUBJECTID=$(basename $IMAGEROOT)


check_fsl
check_cascade

set_filenames

ALL_IMAGES=$(ls ${IMAGEROOT}/${ranges_dir}/brain_*.nii.gz | grep -v t1 )

if [ ! -s $FSL_STD_TRANSFORM ]
then
 echo_fatal "Transform matrix to standard is required but missing.\nThe file should be created in the Cascade pre-processing script. Did you run the Cascade pre-processing script?"
fi
if [ ! ALL_IMAGES ]
then
 echo_fatal "There is no brain image in the image directory.\nThe file should be created in the Cascade pre-processing script. Did you run the Cascade pre-processing script?"
fi

(
set -- $ALL_IMAGES
$CASCADEDIR/c3d_affine_tool -src $STDIMAGE -ref $1 $FSL_STD_TRANSFORM -fsl2ras -oitk $ITK_STD_TRANSFORM 
)

if [ $MODE == "TRAIN" ]
then
  INPUT_ARGS="--transform $ITK_STD_TRANSFORM"
	for img in $ALL_IMAGES
	do
	  INPUT_ARGS="$INPUT_ARGS --input $(range_image $img)"
	done

  for CLASS_INDEX in {1..3}
  do
    runname "Training class ${CLASS_INDEX}"
    (
    set -e
    CLASS_MASK=$IMAGEROOT/${temp_dir}/class_traing_${CLASS_INDEX}_mask.nii.gz
    CLASS_STATE=${STATEIMAGE}_${CLASS_INDEX}.nii.gz
    NEW_CLASS_STATE=${NEWSTATEIMAGE}_${CLASS_INDEX}.nii.gz
    
    fslmaths ${BRAIN_PVE} -thr ${CLASS_INDEX} -uthr ${CLASS_INDEX} -bin ${CLASS_MASK}
    if [ $MASKIMAGE ]
    then
      fslmaths $MASKIMAGE -bin -mul -1 -add 1 -mas ${CLASS_MASK} ${CLASS_MASK}
    else
      fslmaths $(range_image brain_flair.nii.gz) -thr 1 -bin -mul -1 -add 1 -mas ${CLASS_MASK} ${CLASS_MASK}
    fi
    
	  if [ -f $CLASS_STATE ]
	  then
	    $CASCADEDIR/cascade-train $INPUT_ARGS --out $NEW_CLASS_STATE --mask ${CLASS_MASK} --init $CLASS_STATE
	    train_result=$?
	  else
	    $CASCADEDIR/cascade-train $INPUT_ARGS --out $NEW_CLASS_STATE --mask ${CLASS_MASK} --init $STDIMAGE --size 40
	    train_result=$?
	  fi
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

else
  
  mkdir -p $IMAGEROOT/${report_dir}    
  INPUT_ARGS="--transform $ITK_STD_TRANSFORM"
  for img in $ALL_IMAGES
  do
    INPUT_ARGS="$INPUT_ARGS --$(sequence_type $img) $(range_image $img)"
  done
  fslmaths ${BRAIN_WMGM} -mul 0 ${LIKELIHOOD}
  for CLASS_INDEX in {2..3}
  do
	  runname "Calculating likelihood for class ${CLASS_INDEX}"
	  (
    set -e
    CLASS_MASK=$IMAGEROOT/${temp_dir}/class${CLASS_INDEX}_mask.nii.gz
    CLASS_LIKELIHOOD=$IMAGEROOT/${temp_dir}/class${CLASS_INDEX}_likelihood.nii.gz
    CLASS_STATE=${STATEIMAGE}_${CLASS_INDEX}.nii.gz
    fslmaths ${BRAIN_PVE} -thr ${CLASS_INDEX} -uthr ${CLASS_INDEX} -bin ${CLASS_MASK}
    
    (
	    set +e
	    for try in {1..10}
	    do	      
	      $CASCADEDIR/cascade-likelihood $INPUT_ARGS --out ${CLASS_LIKELIHOOD} --state ${CLASS_STATE} --mask ${CLASS_MASK}
	      OUT_RES=$?
	      [ $OUT_RES -eq 0 ] && break 
	      rm ${CLASS_LIKELIHOOD}
	    done
	    exit $OUT_RES
    ) >/dev/null 2>&1
    
    
    fslmaths ${LIKELIHOOD} -add ${CLASS_LIKELIHOOD} ${LIKELIHOOD}
    )
	  if [ $? -eq 0 ]
	  then
	    rundone 0
	  else
	    rundone 1
      rm ${LIKELIHOOD} >/dev/null 2>&1 
	    rm $IMAGEROOT/${temp_dir}/class*_likelihood.nii.gz  >/dev/null 2>&1
	    echo_fatal "Unable to calculate likelihood."
	  fi
  done
fi
echo
