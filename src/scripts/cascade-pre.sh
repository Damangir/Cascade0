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
set -e
###############################################################################
# Usage:
# cascade T1 T1_BRAIN_MASK FLAIR out_dir
###############################################################################
# inputs
###############################################################################
script_name=$0
t1_image=$1
t1_brain_mask=$2
flair_image=$3
out_dir=$4
MIN_PHYS=$5
CHI_CUTOFF=$6
echo "Minimum detection physical size: $MIN_PHYS"
echo "Chi squared cutoff: $CHI_CUTOFF"
###############################################################################
# directory setups
###############################################################################
trans_dir='transformations'
std_space_dir='std_space'
proc_space_dir='proc_space'
t1_space_dir='t1_space'
start_dir=`pwd`
###############################################################################
# options
###############################################################################

CASCADE_BIN=/home/soheil/Apps/Cascade-master/build/cascade
###############################################################################
mkdir -p $out_dir/{$trans_dir,$proc_space_dir,$t1_space_dir}

if [ -s $out_dir/$trans_dir/T1_to_FLAIR.mat ]
then
	echo "Registeration already done"
else
	echo "Registering FLAIR to T1 space"
	flirt -in $flair_image -ref $t1_image -out $out_dir/$t1_space_dir/FLAIR_to_T1 -omat $out_dir/$trans_dir/FLAIR_to_T1.mat -dof 12
	echo "Calculating transform from T1 to FLAIR space"
	convert_xfm -omat $out_dir/$trans_dir/T1_to_FLAIR.mat -inverse $out_dir/$trans_dir/FLAIR_to_T1.mat
	#Clean up
	rm -rf $out_dir/$t1_space_dir/FLAIR_to_T1.nii.gz $out_dir/$trans_dir/FLAIR_to_T1.mat
fi

if [ -s $out_dir/$proc_space_dir/T1_brain.nii.gz ]
then
	echo "T1 brain masking already done"
else
	echo "Masking T1 Brain"
	fslmaths $t1_image -mas $t1_brain_mask $out_dir/$t1_space_dir/T1_brain.nii.gz
	echo "Registering T1 to FLAIR space"
	flirt -in $out_dir/$t1_space_dir/T1_brain.nii.gz -ref $flair_image -out $out_dir/$proc_space_dir/T1_brain.nii.gz -init $out_dir/$trans_dir/T1_to_FLAIR.mat -applyxfm
fi

if [ -s $out_dir/$proc_space_dir/FLAIR_brain.nii.gz ]
then
	echo "FLAIR brain masking already done"
else
	echo "Registering T1 brain mask to FLAIR space"
	flirt -in $t1_brain_mask -ref $flair_image -out $out_dir/$proc_space_dir/T1_brain_mask.nii.gz -init $out_dir/$trans_dir/T1_to_FLAIR.mat -applyxfm
	echo "Masking FLAIR brain"
	fslmaths $flair_image -mas $out_dir/$proc_space_dir/T1_brain_mask.nii.gz $out_dir/$proc_space_dir/FLAIR_brain.nii.gz
	#Clean up
	rm -rf $out_dir/$proc_space_dir/T1_brain_mask.nii.gz
fi

if [ -s $out_dir/$proc_space_dir/T1_brain_pveseg.nii.gz ]
then
	echo "PVE already done"
else
	echo "Calculating PVEs"
	fast -t 1 -o $out_dir/$t1_space_dir/T1_brain -n 3 -b $out_dir/$proc_space_dir/T1_brain.nii.gz
	echo "Copying PVE in FLAIR space"
	cp $out_dir/$t1_space_dir/T1_brain_pveseg.nii.gz $out_dir/$proc_space_dir/T1_brain_pveseg.nii.gz
	#Clean up
	rm -rf  $out_dir/$t1_space_dir/T1_brain_*
fi

if [ -s $out_dir/$proc_space_dir/initial_mask.nii.gz ]
then
	echo "Cascade level 0 already done."
else
	echo "Setting up initial guess (Cascade level 0)"
	# Create a mask of WM-GM as an initial guess (WML is less likely to be in a CSF area even with imperfect PVE)
	fslmaths $out_dir/$proc_space_dir/T1_brain_pveseg.nii.gz -thr 2 $out_dir/$proc_space_dir/initial_mask.nii.gz
	fslmaths $out_dir/$proc_space_dir/initial_mask.nii.gz -bin $out_dir/$proc_space_dir/initial_mask.nii.gz

	# Create an initial aggresve brain mask to remove potentially remaining skull and also outer layer of the cortex.
	# These area are likely to be detected as the WML because of their intensity but they are less likely to be.

	fslmaths $out_dir/$proc_space_dir/T1_brain_pveseg.nii.gz -thr 1 $out_dir/$proc_space_dir/agg_brain_mask0.nii.gz
	fslmaths $out_dir/$proc_space_dir/agg_brain_mask0.nii.gz -bin $out_dir/$proc_space_dir/agg_brain_mask1.nii.gz
	fslmaths $out_dir/$proc_space_dir/agg_brain_mask1.nii.gz -kernel 2D -ero $out_dir/$proc_space_dir/agg_brain_mask2.nii.gz	
	fslmaths $out_dir/$proc_space_dir/agg_brain_mask2.nii.gz -kernel 2D -ero $out_dir/$proc_space_dir/agg_brain_mask.nii.gz	

	# Narawing initial guess
	fslmaths $out_dir/$proc_space_dir/initial_mask.nii.gz -mas $out_dir/$proc_space_dir/agg_brain_mask.nii.gz $out_dir/$proc_space_dir/agg_brain_mask.nii.gz

fi

# We run the actual Cascade runtime anyway! And remove the previous results.
rm -rf $out_dir/$proc_space_dir/wml 
mkdir $out_dir/$proc_space_dir/wml

echo "Running the Cascade (level 1+)"

$CASCADE_BIN -l $out_dir/$proc_space_dir/FLAIR_brain.nii.gz -m $out_dir/$proc_space_dir/initial_mask.nii.gz -t 1 -p ${MIN_PHYS} -o $out_dir/$proc_space_dir/wml/wml_f -c ${CHI_CUTOFF}
fslmaths $out_dir/$proc_space_dir/wml/wml_f_mask.nii.gz -mas $out_dir/$proc_space_dir/initial_mask.nii.gz $out_dir/$proc_space_dir/wml/wml_f_mask.nii.gz


cd $start_dir
