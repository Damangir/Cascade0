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

This script calculates the histogram of the majority of the WM+GM tissues,
discarding simple outliers.

${bold}OPTIONS$normal:
   -r      Image root directory
   -n      Number of bins
   
   -h      Show this message
   -l      Show license
   
EOF
}

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh


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

IMAGEROOT=$(cd "$IMAGEROOT" && pwd -P )
  
if [ ! -d "${IMAGEROOT}" ]
then
  echo_fatal "IMAGEROOT is not a directory."
fi

set_filenames

runname "Calculating effective histogram"
(
set +e
ALL_IMAGES=$(ls ${IMAGEROOT}/${images_dir}/brain_{flair,t1,t2,pd}.nii.gz 2>/dev/null)
set -e
for IMGNAME in $ALL_IMAGES
do
  IMGNAME=$(basename $IMGNAME)
  IMGTYPE=$(basename $IMGNAME .nii.gz)
	HISTOGRAM_FILE=${IMAGEROOT}/${trans_dir}/${IMGTYPE}.hist
  
  if ! [ -s $HISTOGRAM_FILE ]
  then
	  [ ! -s $MASK_FOR_HISTOGRAM ] && ${FSLPREFIX}fslmaths ${BRAIN_WMGM} -mas ${MIDDLE_10} -mas ${IMAGEROOT}/${images_dir}/${IMGNAME} -bin $MASK_FOR_HISTOGRAM
		MASK_OPTIONS="-k $MASK_FOR_HISTOGRAM"
		
		this_maximum=$(${FSLPREFIX}fslstats ${IMAGEROOT}/${images_dir}/${IMGNAME} -P 95 )
		this_histogram=$(${FSLPREFIX}fslstats ${IMAGEROOT}/${images_dir}/${IMGNAME} $MASK_OPTIONS -H $NBIN 0 ${this_maximum} )
		
		this_total=$(echo $this_histogram | sed -e 's/^ *//g' -e 's/ *$//g' -e 's/  */+/g' | bc)
		
		i=0;this_cum=0
		> $HISTOGRAM_FILE
		for elem in $this_histogram
		do
		  this_elem=$(bc -l <<< "$elem / ${this_total}" )
		  this_cum=$(bc -l <<< "$this_cum + $this_elem" )
		  this_bin=$(bc -l <<< "($i + 0.5) * ${this_maximum} / $NBIN " )
		     
		  echo $i $this_bin $this_elem $this_cum >> $HISTOGRAM_FILE
		  i=$(( $i + 1 ))
		done
  fi
done
)
rundone $?
