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
   -l      Show licence
EOF
}

source $(dirname $0)/cascade-setup.sh
source $(dirname $0)/cascade-util.sh

MIN_PHYS=20
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

mkdir -p $IMAGEROOT/${report_dir}
IMAGEROOT=$(readlink -f $IMAGEROOT)
SUBJECTID=$(basename $IMAGEROOT)


check_fsl
check_cascade

set_filenames
get_allimages

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
$CASCADEDIR/c3d_affine_tool -ref $STDIMAGE -src $1 $FSL_STD_TRANSFORM -fsl2ras -oitk $ITK_STD_TRANSFORM 
)

echo "${bold}Running the Cascade pipeline${normal}"

####### POSTPROCESSING
echo "${bold}Post-processing${normal}"
runname "Processing likelihood"
# Threshold likelihood
fslmaths $LIKELIHOOD -abs $ABS_LIKELIHOOD
# fslmaths $LIKELIHOOD -thr $CHI_CUTOFF -bin $OUTMASK
echo
echo $CASCADEDIR/cascade-property-filter --input $OUTMASK --out $OUTMASK --property PhysicalSize -- threshold $MIN_PHYS

rundone $?

####### REPORTING  
echo "${bold}Reporting${normal}"
mkdir -p $IMAGEROOT/${report_dir}/overlays
if [ -f $OUTMASK ]
then
	echo "\"ID\",\"CSF VOL\",\"GM VOL\",\"WM VOL\",\"WML VOL\"">${REPORTCSV}
	echo -n "\"$SUBJECTID\",">>${REPORTCSV}
	fslstats $IMAGEROOT/${temp_dir}/brain_pve_0.nii.gz -M -V | awk '{ printf "%.0f,",  $1 * $3 }' >> ${REPORTCSV} 
	fslstats $IMAGEROOT/${temp_dir}/brain_pve_1.nii.gz -M -V | awk '{ printf "%.0f,",  $1 * $3 }' >> ${REPORTCSV}
	fslstats $IMAGEROOT/${temp_dir}/brain_pve_2.nii.gz -M -V | awk '{ printf "%.0f,",  $1 * $3 }' >> ${REPORTCSV}
	fslstats $IMAGEROOT/${report_dir}/wm.nii.gz -M -V | awk '{ printf "%.0f,",  $1 * $3 }' >> ${REPORTCSV}

	for img in $ALL_IMAGES
	do
	  image_type=$(basename $img|sed "s/brain_//g"|sed "s/\..*//g")
	  $CASCADEDIR/cascade-report --input $img --mask $IMAGEROOT/${report_dir}/wm.nii.gz --out $IMAGEROOT/${report_dir}/overlays/wm_on_${image_type}
	  montage $IMAGEROOT/${report_dir}/overlays/wm_on_${image_type}*.png $IMAGEROOT/${report_dir}/overlays/wm_on_${image_type}.png 
	done
fi  