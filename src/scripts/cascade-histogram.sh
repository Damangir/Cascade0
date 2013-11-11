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

This script creats a heuristic based mask for possible position of a lesion

${bold}OPTIONS$normal:
   -r      Image root directory
   -n      Number of bins
   
   -h      Show this message
   -l      Show licence
   
EOF
}

source $(dirname $0)/cascade-setup.sh
source $(dirname $0)/cascade-util.sh

NBIN=100
while getopts “hr:n:l” OPTION
do
  case $OPTION in
## Subject directory
    r)
      IMAGEROOT=$OPTARG
      ;;
## Settings
    n)
      NBIN=$OPTARG
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

IMAGEROOT=$(readlink -f $IMAGEROOT)     
if [ ! -d "${IMAGEROOT}" ]
then
  echo_fatal "IMAGEROOT is not a directory."
fi

check_fsl
check_cascade
set_filenames

TMP_DIR=$(mktemp -d)
trap "rm -rf ${TMP_DIR}" EXIT

runname "Calculating effective histogram"
(
set -e
ALL_IMAGES=$(ls ${IMAGEROOT}/${images_dir}/brain_{flair,t1,t2,pd}.nii.gz 2>/dev/null)
for IMGNAME in $ALL_IMAGES
do
  IMGNAME=$(basename $IMGNAME)
  IMGTYPE=$(basename $IMGNAME .nii.gz)
	HISTOGRAM_FILE=${IMAGEROOT}/${trans_dir}/${IMGTYPE}.hist
	MASK_IMAGE=${TMP_DIR}/mask.nii.gz
  ${FSLPREFIX}fslmaths ${IMAGEROOT}/${images_dir}/WhiteMatter+GrayMatter.nii.gz -mas ${IMAGEROOT}/${std_dir}/BrainMiddleMask10.nii.gz -mas ${IMAGEROOT}/${images_dir}/${IMGNAME} -bin $MASK_IMAGE
	MASK_OPTIONS="-k $MASK_IMAGE"
	
	this_maximum=$(${FSLPREFIX}fslstats ${IMAGEROOT}/${images_dir}/${IMGNAME} -P 95 )
	this_histogram=$(${FSLPREFIX}fslstats ${IMAGEROOT}/${images_dir}/${IMGNAME} $MASK_OPTIONS -H $NBIN 0 ${this_maximum} )
	
	this_total=$(echo $this_histogram | sed -e 's/^ *//g' -e 's/ *$//g' -e 's/  */+/g' | bc)
	 
	i=0;this_cum=0
	> $HISTOGRAM_FILE
	for elem in $this_histogram
	do
	  this_elem=$(echo "$elem / ${this_total}" | bc -l )
	  this_cum=$(echo "$this_cum + $this_elem" | bc -l )
	  this_bin=$(echo "($i + 0.5) * ${this_maximum} / $NBIN " | bc -l )   
	  echo $i $this_bin $this_elem $this_cum >> $HISTOGRAM_FILE
	  i=$(( $i + 1 ))
	done
done
)
rundone $?