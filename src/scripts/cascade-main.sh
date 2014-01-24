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
   -l      Show license
EOF
}

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh


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
      IMAGEROOT="$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")"
      ;;
    n)
      NEWSTATEIMAGE="$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")"
      MODE="TRAIN"
      ;;
    m)
      MASKIMAGE="$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")"
      MODE="TRAIN"
      ;;
    s)
      STATEIMAGE="$(cd $(dirname "$OPTARG") && pwd -P )/$(basename "$OPTARG")"
      ;;
    f)
      FOURCERUN=
      ;;
    v)
      VERBOSE=1
      ;;
    l)
      cascade_copyright
      cascade_license
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

IMAGEROOT=$(cd "$IMAGEROOT" && pwd -P )
SUBJECTID=$(basename $IMAGEROOT)



set_filenames

set +e
ALL_IMAGES=$(ls ${IMAGEROOT}/${images_dir}/brain_{flair,t1,t2,pd}.nii.gz 2>/dev/null)
set -e  

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
$CASCADEDIR/c3d_affine_tool -src $STD_IMAGE -ref $1 $FSL_STD_TRANSFORM -fsl2ras -oitk $ITK_STD_TRANSFORM 
)

if [ $MODE == "TRAIN" ]
then

  for CLASS_INDEX in {2..3}
  do
    runname "Training on $(tissue_name ${CLASS_INDEX})"
    (
    set -e
    
    CLASS_MASK=${SAFE_TMP_DIR}/class_traing_${CLASS_INDEX}_mask.nii.gz
    
    ${FSLPREFIX}fslmaths ${BRAIN_PVE} -thr ${CLASS_INDEX} -uthr ${CLASS_INDEX} -bin ${CLASS_MASK}
    if [ $MASKIMAGE ]
    then
      ${FSLPREFIX}fslmaths $MASKIMAGE -bin -mul -1 -add 1 -mas ${CLASS_MASK} ${CLASS_MASK}
    else
      ${FSLPREFIX}fslmaths $HYP_MASK -mul -1 -add 1 -mas ${CLASS_MASK} ${CLASS_MASK}
    fi
    
		for img in $ALL_IMAGES
		do
		  IMAGE_NAME=$(sequence_name $img)
		  RANGE_IMAGE=$(range_image $img)
	    CLASS_STATE=${STATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}.nii.gz
	    NEW_CLASS_STATE=${NEWSTATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}.nii.gz
	    
		  INPUT_ARGS="--transform $ITK_STD_TRANSFORM --input $RANGE_IMAGE"
		  if [ -f $CLASS_STATE ]
		  then
		    $CASCADEDIR/cascade-train $INPUT_ARGS --out $NEW_CLASS_STATE --mask ${CLASS_MASK} --init $CLASS_STATE
		    train_result=$?
		  else
		    $CASCADEDIR/cascade-train $INPUT_ARGS --out $NEW_CLASS_STATE --mask ${CLASS_MASK} --init $STD_IMAGE --size 40
		    train_result=$?
		  fi
		    
	  done
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
  ${FSLPREFIX}fslmaths ${BRAIN_PVE} -mul 0 ${LIKELIHOOD}
  
  W_total=$(total_weight)
  
  for CLASS_INDEX in {2..3}
  do
    runname "Calculating likelihood for $(tissue_name ${CLASS_INDEX})"
    (
    set -e
    CLASS_MASK=${SAFE_TMP_DIR}/class_${CLASS_INDEX}_mask.nii.gz
    ${FSLPREFIX}fslmaths ${BRAIN_PVE} -thr ${CLASS_INDEX} -uthr ${CLASS_INDEX} -bin ${CLASS_MASK}
    
    for img in $ALL_IMAGES
    do
      IMAGE_NAME=$(sequence_name $img)
      IMAGE_TYPE=$(sequence_type $img)
      IMAGE_WEIGHT=$( bc -l <<< "$(sequence_weight $img) / $W_total" )
      RANGE_IMAGE=$(range_image $img)
      
      CLASS_STATE=${STATEIMAGE}_${IMAGE_NAME}_${CLASS_INDEX}.nii.gz
	    CLASS_LIKELIHOOD=$IMAGEROOT/${temp_dir}/${IMAGE_NAME}_class_${CLASS_INDEX}_likelihood.nii.gz
      
      INPUT_ARGS="--transform $ITK_STD_TRANSFORM --${IMAGE_TYPE} ${RANGE_IMAGE}"  
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
	      
      ${FSLPREFIX}fslmaths ${CLASS_LIKELIHOOD} -mul $IMAGE_WEIGHT -add ${LIKELIHOOD} ${LIKELIHOOD}

    done
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
  
  if [ -s $HYP_MASK ]
  then
    runname "Filtering base on heuristic mask"
    ${FSLPREFIX}fslmaths ${LIKELIHOOD} -mas ${HYP_MASK} -abs ${LIKELIHOOD}
    rundone $?
  else
    runname "Filtering through WML direction"
    ${FSLPREFIX}fslmaths ${LIKELIHOOD} -thr 0 ${LIKELIHOOD}
    rundone $?
  fi
  ${FSLPREFIX}fslmaths ${LIKELIHOOD} -sub 0.85 -mul -40 -exp -add 1 -recip ${LIKELIHOOD}
fi
echo