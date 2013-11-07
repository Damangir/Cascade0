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

   -l      Show licence
   
EOF
}

source $(dirname $0)/cascade-setup.sh
source $(dirname $0)/cascade-util.sh


IMAGEROOT=.
while getopts “hr:l” OPTION
do
  case $OPTION in
## Subject directory
    r)
      IMAGEROOT=$OPTARG
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

IMAGEROOT=$(readlink -f $IMAGEROOT)     
echo "Preprocessing subject at: ${IMAGEROOT}"

check_fsl
check_cascade
set_filenames

mkdir -p ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir}}

runname "Light part on FLAIR or T2"
(
set -e
cp $BRAIN_MASK $HYP_MASK
if [ -s $FLAIR_BRAIN ]
then
  flair_thresh=$(${FSLPREFIX}fslstats $FLAIR_BRAIN -k $BRAIN_WM -P 50)
  ${FSLPREFIX}fslmaths $FLAIR_BRAIN -thr $flair_thresh -mul $HYP_MASK -bin $HYP_MASK
fi
if [ -s $T2_BRAIN ]
then
  t2_thresh=$(${FSLPREFIX}fslstats $T2_BRAIN -k $BRAIN_WM -P 50)
  ${FSLPREFIX}fslmaths $T2_BRAIN -thr $t2_thresh -mul $HYP_MASK -bin $HYP_MASK
fi
)
rundone $?

runname "Not bright on T1"
(
set -e
if [ -s $T1_BRAIN ]
then
  t1_thresh=$(${FSLPREFIX}fslstats $T1_BRAIN -k $BRAIN_WM -P 90)
  ${FSLPREFIX}fslmaths $T1_BRAIN -uthr $t1_thresh -mul $HYP_MASK -bin $HYP_MASK
fi
)
rundone $?

echo "Heuristic mask created for subject: ${IMAGEROOT}"