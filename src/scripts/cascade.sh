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

###############################################################################
# Usage:
# cascade T1 FLAIR out_dir
###############################################################################
# inputs
###############################################################################
script_name=$0
t1_image=$1
flair_image=$2
out_dir=$3
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
bet_options='-S -g 0.1 -f 0.4 -m'

echo "Searching for MNI152lin_T1_2mm_brain.nii.gz"
std_space=`locate MNI152lin_T1_2mm_brain.nii.gz|head -n 1`
if [ ! -r $std_space ]
then
  echo "Can not locate the standard FSL brain." >&2
  exit 2
fi
echo "Standard FSL brain found at `dirname $std_space`"

###############################################################################
mkdir -p $out_dir/{$trans_dir,$proc_space_dir,$t1_space_dir,$std_space_dir}

echo "Brain extraction on T1"
bet $t1_image $out_dir/$t1_space_dir/T1_brain $bet_options

echo "Registering T1 to standard space"
flirt -in $out_dir/$t1_space_dir/T1_brain.nii.gz -ref $std_space -out $out_dir/$std_space_dir/T1_brain.nii.gz -omat $out_dir/$trans_dir/T1_to_STD.mat -dof 12
echo "Calculating transform from T1 to standard space"
convert_xfm -omat $out_dir/$trans_dir/STD_to_T1.mat -inverse $out_dir/$trans_dir/T1_to_STD.mat
echo "Registering FLAIR to T1 space"
flirt -in $flair_image -ref $t1_image -out $out_dir/$t1_space_dir/FLAIR_to_T1 -omat $out_dir/$trans_dir/FLAIR_to_T1.mat -dof 12
echo "Calculating transform from T1 to FLAIR space"
convert_xfm -omat $out_dir/$trans_dir/T1_to_FLAIR.mat -inverse $out_dir/$trans_dir/FLAIR_to_T1.mat

echo "Calculating PVEs"
fast -t 1 -o $out_dir/$t1_space_dir/T1_brain -n 3 -b -a $out_dir/$trans_dir/STD_to_T1.mat --Prior $out_dir/$t1_space_dir/T1_brain.nii.gz

echo "Registering T1 to FLAIR space"
flirt -in $out_dir/$t1_space_dir/T1_brain.nii.gz -ref $flair_image -out $out_dir/$proc_space_dir/T1_brain.nii.gz -init $out_dir/$trans_dir/T1_to_FLAIR.mat -applyxfm
echo "Registering T1 brain mask to FLAIR space"
flirt -in $out_dir/$t1_space_dir/T1_brain_mask.nii.gz -ref $flair_image -out $out_dir/$proc_space_dir/T1_brain_mask.nii.gz -init $out_dir/$trans_dir/T1_to_FLAIR.mat -applyxfm
echo "Registering PVE in FLAIR space"
flirt -in $out_dir/$t1_space_dir/T1_brain_pve_0.nii.gz -ref $flair_image -out $out_dir/$proc_space_dir/T1_brain_pve_0.nii.gz -init $out_dir/$trans_dir/T1_to_FLAIR.mat -applyxfm
flirt -in $out_dir/$t1_space_dir/T1_brain_pve_1.nii.gz -ref $flair_image -out $out_dir/$proc_space_dir/T1_brain_pve_1.nii.gz -init $out_dir/$trans_dir/T1_to_FLAIR.mat -applyxfm
flirt -in $out_dir/$t1_space_dir/T1_brain_pve_2.nii.gz -ref $flair_image -out $out_dir/$proc_space_dir/T1_brain_pve_2.nii.gz -init $out_dir/$trans_dir/T1_to_FLAIR.mat -applyxfm
flirt -in $out_dir/$t1_space_dir/T1_brain_pveseg.nii.gz -ref $flair_image -out $out_dir/$proc_space_dir/T1_brain_pveseg.nii.gz -init $out_dir/$trans_dir/T1_to_FLAIR.mat -applyxfm

echo "Masking FLAIR brain"
fslmaths $flair_image -mas $out_dir/$proc_space_dir/T1_brain_mask.nii.gz $out_dir/$proc_space_dir/FLAIR_brain.nii.gz

cd $start_dir
