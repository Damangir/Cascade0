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
SUBJECTID=$(basename $IMAGEROOT)



set_filenames
# first we need to remove previous reports.
find $IMAGEROOT/${report_dir} -type f -not -wholename "${LIKELIHOOD}" -print0 | xargs -0 rm -f

echo "${bold}The Cascade Reporter${normal}"
####### POSTPROCESSING
runname "Processing likelihood"
(
set -e
# Threshold likelihood
${FSLPREFIX}fslmaths $LIKELIHOOD -thr $CHI_CUTOFF -bin $OUTMASK
${CASCADEDIR}/cascade-property-filter --input $OUTMASK --out $OUTMASK --property PhysicalSize --threshold $MIN_PHYS
${FSLPREFIX}fslmaths $OUTMASK -bin $OUTMASK
${FSLPREFIX}fslmaths $OUTMASK -bin -mul $LIKELIHOOD -min 1 $PVALUEIMAGE
)
rundone $?
####### REPORTING  
runname "Creating report"
(
set -e
mkdir -p $IMAGEROOT/${report_dir}/overlays
if [ -f $OUTMASK ]
then
	echo -n "\"ID\",\"CSF VOL\",\"GM VOL\",\"WM VOL\",\"WML VOL (p-Value)\"">${REPORTCSV}
  
  
	if [ "$STD_ATLAS" ] && [ -e "$ATLAS" ]
	then
	  atlas_labels=($(get_atlas_label $STD_ATLAS))
		for lvl in "${!atlas_labels[@]}"
	  do
	    [[ $lvl == 0 ]] && continue
	    echo -n ",\"${atlas_labels[${lvl}]}\"" >> ${REPORTCSV}
	  done
  fi

  echo  >> ${REPORTCSV}
	echo -n "\"$SUBJECTID\"">>${REPORTCSV}
	${FSLPREFIX}fslstats $BRAIN_CSF   -M -V | awk '{ printf ",%.0f",  $1 * $3 }' >> ${REPORTCSV} 
	${FSLPREFIX}fslstats $BRAIN_GM    -M -V | awk '{ printf ",%.0f",  $1 * $3 }' >> ${REPORTCSV}
	${FSLPREFIX}fslstats $BRAIN_WM    -M -V | awk '{ printf ",%.0f",  $1 * $3 }' >> ${REPORTCSV}
  ${FSLPREFIX}fslstats $PVALUEIMAGE -M -V | awk '{ printf ",%.0f",  $1 * $3 }' >> ${REPORTCSV}
  
  if [ "$STD_ATLAS" ] && [ -e "$ATLAS" ]
  then
    for lvl in "${!atlas_labels[@]}"
    do
      [[ $lvl == 0 ]] && continue
  	  tmp_image=${SAFE_TMP_DIR}/atlas_level.nii.gz
	    ${FSLPREFIX}fslmaths $ATLAS -thr $lvl -uthr $lvl -bin -mul $PVALUEIMAGE $tmp_image
	    ${FSLPREFIX}fslstats $tmp_image -M -V | awk '{ printf ",%.0f",  $1 * $3 }' >> ${REPORTCSV}
    done
  fi 
  echo >> ${REPORTCSV}
fi
)
rundone $?
