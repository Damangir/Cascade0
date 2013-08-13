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
   -c      Chi-squared cutoff
   -p      Minimum physical size
   -f      Fource run all steps
   -v      Verbose
   -l      Show licence
EOF
}

source $(dirname $0)/cascade-util.sh

trans_dir='transformations'
proc_space_dir='proc_space'
t1_space_dir='t1_space'

CASCADEDIR=/home/soheil/workspace/Cascade/build

MIN_PHYS=0
CHI_CUTOFF=0.9
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

echo "${bold}System compatibility check${normal}"
runname "  Checking Cascade executable"
for ce in cascade-{outlier,smoothing}
do
  if [ ! -x $CASCADEDIR/$ce ]
  then
    rundone 1
    echo_fatal "Cascade executable ${underline}${ce}${normal} is not available. Please check your Cascade installation."
  fi
done
rundone 0

runname "  Checking FSL installation"
if [ ! $FSLDIR ]
then
  rundone 1
  echo_fatal "Can not find FSL installation."
else
  for ce in {fslmaths,}
  do
    if [ ! -x $FSLDIR/bin/$ce ]
    then
      rundone 1
      echo_fatal "$ce executable is not available. Please check your FSL installation."
    fi
  done

  if echo "$LD_LIBRARY_PATH" | grep -qv "$FSLDIR/bin"
  then
	  OLD_LD="$LD_LIBRARY_PATH"
	  trap "LD_LIBRARY_PATH=$OLD_LD" EXIT
	  export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${FSLDIR}/bin 
  fi
  
fi
rundone 0

echo "${bold}Pre-processing check${normal}"
runname "  Checking directory structure"
(
for d in {$tradsfns_dir,$proc_space_dir,$t1_space_dir}
do
  if [ ! -d $IMAGEROOT/${d} ]
  then
    rundone 1
    echo_warning "${underline}$IMAGEROOT${normal} is not a valid Cascade directory structure."
    exit 1
  fi
done
)
[ $? -eq 0 ] && rundone 0

runname "  Checking required files"
for d in $proc_space_dir/{T1_brain_pveseg.nii.gz,FLAIR_brain.nii.gz}
do
  if [ ! -f $IMAGEROOT/${d} ]
  then
    rundone 1
    echo_fatal "${underline}$IMAGEROOT/${d}${normal} is required but missing.\nThe file should be created in the Cascade pre-processing script. Did you run the Cascade pre-processing script?"
  fi
done
rundone 0

echo "${bold}Running the Cascade pipeline${normal}"
runname "  Setting up initial mask (Cascade level 0)"
if [ $FOURCERUN ] && [ -s $IMAGEROOT/$proc_space_dir/initial_mask.nii.gz ]
then
  rundone 0 "CACHED"
else
	(
  # Create a mask of WM-GM as an initial guess (WML is less likely to be in a CSF area even with imperfect PVE)
  fslmaths $IMAGEROOT/$proc_space_dir/T1_brain_pveseg.nii.gz -thr 2 -bin $IMAGEROOT/$proc_space_dir/initial_mask.nii.gz
  
  # Create an initial aggresve brain mask to remove potentially remaining skull and also outer layer of the cortex.
  # These area are likely to be detected as the WML because of their intensity but they are less likely to be.
    fslmaths $IMAGEROOT/$proc_space_dir/T1_brain_pveseg.nii.gz -thr 1 -bin -kernel 2D -ero $IMAGEROOT/$proc_space_dir/agg_brain_mask.nii.gz
  for i in range 3
  do
    fslmaths $IMAGEROOT/$proc_space_dir/agg_brain_mask.nii.gz -kernel 2D -ero $IMAGEROOT/$proc_space_dir/agg_brain_mask.nii.gz
  done

  # Narrawing initial mask
  fslmaths $IMAGEROOT/$proc_space_dir/initial_mask.nii.gz -mas $IMAGEROOT/$proc_space_dir/agg_brain_mask.nii.gz $IMAGEROOT/$proc_space_dir/initial_mask.nii.gz	    
	) 1>/dev/null 2>/dev/null
  rundone $?

  fslmaths $IMAGEROOT/$proc_space_dir/T1_brain.nii.gz -mas $IMAGEROOT/$proc_space_dir/initial_mask.nii.gz $IMAGEROOT/$proc_space_dir/T1_brain.nii.gz    
  fslmaths $IMAGEROOT/$proc_space_dir/FLAIR_brain.nii.gz -mas $IMAGEROOT/$proc_space_dir/initial_mask.nii.gz $IMAGEROOT/$proc_space_dir/FLAIR_brain.nii.gz    
		
	checkmsg "  Cleaning up"	"rm $IMAGEROOT/$proc_space_dir/agg_brain_mask.nii.gz $IMAGEROOT/$proc_space_dir/initial_mask.nii.gz"
fi
exit 0
# We run the actual Cascade runtime anyway! And remove the previous results.
rm -rf $IMAGEROOT/$proc_space_dir/wml 
mkdir $IMAGEROOT/$proc_space_dir/wml

checkmsg "  Creating potential map" "$CASCADEDIR/cascade-outlier -l $IMAGEROOT/$proc_space_dir/FLAIR_brain.nii.gz -m $IMAGEROOT/$proc_space_dir/initial_mask.nii.gz -o $IMAGEROOT/$proc_space_dir/wml/wml_f.nii.gz"

runname "  Creating mask"
(
	set -e
  fslmaths $IMAGEROOT/$proc_space_dir/wml/wml_f.nii.gz -thr $CHI_CUTOFF -bin $IMAGEROOT/$proc_space_dir/wml/wml_m.nii.gz
  NUM_LABELS=$($CASCADEDIR/cascade-labeler -i $IMAGEROOT/$proc_space_dir/wml/wml_m.nii.gz -o $IMAGEROOT/$proc_space_dir/wml/wml_l.nii.gz -p $MIN_PHYS)  
	#>$IMAGEROOT/$proc_space_dir/wml/labels.txt
	#for LAB_ID in `seq $NUM_LABELS`
	#do
	  #fslmaths $IMAGEROOT/$proc_space_dir/wml/wml_l.nii.gz -thr $LAB_ID -uthr $LAB_ID $IMAGEROOT/$proc_space_dir/wml/wml_$LAB_ID.nii.gz
	  
	  #MAXLOC=$($CASCADEDIR/cascade-maxmask -i $IMAGEROOT/$proc_space_dir/wml/wml_f.nii.gz -m $IMAGEROOT/$proc_space_dir/wml/wml_$LAB_ID.nii.gz)
	  #echo $MAXLOC >> $IMAGEROOT/$proc_space_dir/wml/labels.txt
	  #$CASCADEDIR/cascade-grow -s $MAXLOC -i $IMAGEROOT/$proc_space_dir/FLAIR_brain.nii.gz -o $IMAGEROOT/$proc_space_dir/wml/wml_$LAB_ID.nii.gz -m 0.2 -n 1
	  #if [ -e $IMAGEROOT/$proc_space_dir/wml/wml_mask.nii.gz ]
	  #then
	    #  fslmaths $IMAGEROOT/$proc_space_dir/wml/wml_$LAB_ID.nii.gz -add $IMAGEROOT/$proc_space_dir/wml/wml_mask.nii.gz $IMAGEROOT/$proc_space_dir/wml/wml_mask.nii.gz
	  #else
	    #  cp $IMAGEROOT/$proc_space_dir/wml/wml_$LAB_ID.nii.gz $IMAGEROOT/$proc_space_dir/wml/wml_mask.nii.gz
	  #fi
	  #rm -f $IMAGEROOT/$proc_space_dir/wml/wml_$LAB_ID.nii.gz
	#done
	#fslmaths $IMAGEROOT/$proc_space_dir/wml/wml_mask.nii.gz -bin $IMAGEROOT/$proc_space_dir/wml/wml_mask.nii.gz
) 
rundone $?

echo "${bold}Post-processing${normal}"
echo "${bold}Reporting${normal}"
