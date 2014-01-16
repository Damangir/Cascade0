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

ALL_IMAGES=$(ls ${IMAGEROOT}/${images_dir}/brain_{flair,t2,t1,pd}.nii.gz 2>/dev/null)
for img in $ALL_IMAGES
do
  do_overlay $img 
done