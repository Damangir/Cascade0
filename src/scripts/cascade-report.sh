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

# first we need to remove previous reports.
find $IMAGEROOT/${report_dir} -type f -not -wholename "${LIKELIHOOD}" -print0 | xargs -0 rm -f

echo "${bold}The Cascade Reporter${normal}"
####### POSTPROCESSING
runname "Processing likelihood"
(
set -e
# Threshold likelihood
fsl5.0-fslmaths $LIKELIHOOD -thr $CHI_CUTOFF -bin $OUTMASK
fsl5.0-fslmaths $BRAIN_WMGM -sub $BRAIN_THIN_GM -thr 0 -bin -mul $OUTMASK $OUTMASK
$CASCADEDIR/cascade-property-filter --input $OUTMASK --out $OUTMASK --property PhysicalSize --threshold $MIN_PHYS
fsl5.0-fslmaths $OUTMASK -bin $OUTMASK
fsl5.0-fslmaths $OUTMASK -bin -mul $LIKELIHOOD -min 1 $PVALUEIMAGE
fsl5.0-fslmaths $OUTMASK -bin -mul $BRAIN_WM -bin -mul $LIKELIHOOD -min 1 $PVALUEIMAGE_CONS
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
  
  
	if [ -e "$PROC_ATLAS" ]
	then
		for lvl in $(seq $(fsl5.0-fslstats $PROC_ATLAS -R))
	  do
	    [ "$(echo $lvl '==' 0 | bc)" -eq 1 ] && continue
	    echo -n ",\"atlas.level.`printf "%.0f" ${lvl}`\"" >> ${REPORTCSV}
	  done
  fi

  echo  >> ${REPORTCSV}
	echo -n "\"$SUBJECTID\",">>${REPORTCSV}
	fslstats $IMAGEROOT/${temp_dir}/brain_pve_0.nii.gz     -M -V | awk '{ printf "%.0f,",  $1 * $3 }' >> ${REPORTCSV} 
	fslstats $IMAGEROOT/${temp_dir}/brain_pve_mod_1.nii.gz -M -V | awk '{ printf "%.0f,",  $1 * $3 }' >> ${REPORTCSV}
	fslstats $IMAGEROOT/${temp_dir}/brain_pve_mod_2.nii.gz -M -V | awk '{ printf "%.0f,",  $1 * $3 }' >> ${REPORTCSV}
  fslstats $PVALUEIMAGE                                  -M -V | awk '{ printf "%.0f",  $1 * $3 }' >> ${REPORTCSV}
  
  if [ -e "$PROC_ATLAS" ]
  then
    for lvl in $(seq $(fsl5.0-fslstats $PROC_ATLAS -R))
    do
      [ "$(echo $lvl '==' 0 | bc -l)" -eq 1 ] && continue
  	  tmp_image=$IMAGEROOT/${temp_dir}/temp.nii.gz
	    fsl5.0-fslmaths $PROC_ATLAS -thr $lvl -uthr $lvl -bin -mul $PVALUEIMAGE $tmp_image
	    fslstats $tmp_image -M -V | awk '{ printf ",%.0f",  $1 * $3 }' >> ${REPORTCSV}
    done
  fi 
  
  echo >> ${REPORTCSV}
  ALL_IMAGES=$(ls ${IMAGEROOT}/${images_dir}/brain_flair.nii.gz | grep -v pve| grep -v mixel )
	for img in $ALL_IMAGES
	do
	  image_type=$(basename $img|sed "s/brain_//g"|sed "s/\..*//g")
	  $CASCADEDIR/cascade-report --input $img --mask $OUTMASK --out $IMAGEROOT/${report_dir}/overlays/wm_on_${image_type}
	  montage $IMAGEROOT/${report_dir}/overlays/wm_on_${image_type}_*.png $IMAGEROOT/${report_dir}/overlays/wm_on_${image_type}.png 
	done
fi
)
rundone $?
