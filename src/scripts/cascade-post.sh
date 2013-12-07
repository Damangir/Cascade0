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
   -c      Chi-squared cutoff
   -p      Minimum physical size
Misc.:
   -h      Show this message
   -f      Fource run all steps
   -v      Verbose
   -l      Show license
EOF
}

source $(dirname $0)/cascade-setup.sh


MIN_PHYS=100
CHI_CUTOFF=0.875
IMAGEROOT=.
VERBOSE=
FOURCERUN=1
while getopts “hr:p:c:vfl” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    r)
      IMAGEROOT=`readlink -f $OPTARG`
      ;;
    c)
      CHI_CUTOFF=$OPTARG
      ;;
    p)
      MIN_PHYS=$OPTARG
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

mkdir -p $IMAGEROOT/${report_dir}
IMAGEROOT=$(readlink -f $IMAGEROOT)

set_filenames
# first we need to remove previous reports.
find $IMAGEROOT/${report_dir} -type f -not -wholename "${LIKELIHOOD}" -print0 | xargs -0 rm -f

echo "${bold}The Cascade Postprocessing${normal}"
runname "Processing likelihood"
(
set -e
# Threshold likelihood
${CASCADEDIR}/cascade-statistics-filter -i $LIKELIHOOD -b $CHI_CUTOFF -o $PVALUEIMAGE --property Sum --threshold $MIN_PHYS
${FSLPREFIX}fslmaths $PVALUEIMAGE -kernel 2D -ero -dilM $PVALUEIMAGE
${FSLPREFIX}fslmaths $PVALUEIMAGE -bin $OUTMASK
)
rundone $?