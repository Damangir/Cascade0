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
   -h      Show this message
   -r      Image root directory

   -l      Show license
   
EOF
}

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh



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
  echo_fatal "IMAGEROOT is not a directory."
fi


set_filenames

mkdir -p ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir}}

echo "${bold}Calculating heuristics${normal}"

[ ! -s $MASK_FOR_HISTOGRAM ] && ${FSLPREFIX}fslmaths ${BRAIN_WMGM} -mas ${MIDDLE_10} -mas ${T1_BRAIN} -bin $MASK_FOR_HISTOGRAM

runname "    Heuristic: Light part on FLAIR or T2"
(
set -e
cp $MIDDLE $HYP_MASK
if [ -s $FLAIR_BRAIN ]
then
  PERCENTILE=($(${FSLPREFIX}fslstats $FLAIR_BRAIN -k ${MASK_FOR_HISTOGRAM} -P 50 -P 60 -P 70 -P 80 -P 90 -P 95))

  ${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr ${PERCENTILE[0]} -mul $HYP_MASK -bin $HYP_MASK

  ${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr ${PERCENTILE[5]} -mas $OUTER_10 -mas ${BRAIN_WM} -add $MIDDLE_10 -bin -mul $HYP_MASK -bin $HYP_MASK 
fi
if [ -s $T2_BRAIN ]
then
  t2_thresh=$(${FSLPREFIX}fslstats $T2_BRAIN -k ${MASK_FOR_HISTOGRAM} -P 50)
  ${FSLPREFIX}fslmaths $T2_BRAIN -thr $t2_thresh -mul $HYP_MASK -bin $HYP_MASK
fi
)
rundone $?

runname "    Heuristic: Not bright on T1"
(
set -e
if [ -s $T1_BRAIN ]
then
  t1_thresh=$(${FSLPREFIX}fslstats $T1_BRAIN -k $BRAIN_WM -P 90)
  ${FSLPREFIX}fslmaths $T1_BRAIN -uthr $t1_thresh -mul $HYP_MASK -bin $HYP_MASK
fi
)
rundone $?