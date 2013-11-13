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

# check if stdout is a terminal...
if [ -t 1 ]; then
  # see if it supports colors...
  ncolors=$(tput colors)
  if test -n "$ncolors" && test $ncolors -ge 8; then
    bold="$(tput bold)"
    underline="$(tput smul)"
    standout="$(tput smso)"
    normal="$(tput sgr0)"
    black="$(tput setaf 0)"
    red="$(tput setaf 1)"
    green="$(tput setaf 2)"
    yellow="$(tput setaf 3)"
    blue="$(tput setaf 4)"
    magenta="$(tput setaf 5)"
    cyan="$(tput setaf 6)"
    white="$(tput setaf 7)"
    header_format="\n${bold}${underline}##   "
  fi
fi

SAFE_TMP_DIR=$(mktemp -d)
trap "rm -rf ${SAFE_TMP_DIR}" EXIT

check_cascade()
{
for ce in {cascade-{range,train,likelihood,report,inspect,property-filter},c3d_affine_tool}
do
  if [ ! -x $CASCADEDIR/$ce ]
  then
    echo_fatal "Cascade executable ${underline}${ce}${normal} is not available. Please check your Cascade installation."
  fi
done
STD_MIDDLE=$MASK_ROOT/MNI152_T1_1mm_middle_brain_mask.nii.gz
STD_MIDDLE_10=$MASK_ROOT/MNI152_T1_1mm_middle_brain_mask_err_10.nii.gz
STD_OUTER_10=$MASK_ROOT/MNI152_T1_1mm_middle_brain_mask_outer_10.nii.gz
STD_MIDDLE_20=$MASK_ROOT/MNI152_T1_1mm_middle_brain_mask_err_20.nii.gz
STD_OUTER_20=$MASK_ROOT/MNI152_T1_1mm_middle_brain_mask_outer_20.nii.gz

STD_IMAGE=$STANDARD_ROOT/MNI152_T1_1mm_brain.nii.gz

if [ ! -f $STD_IMAGE ]
then
  echo_fatal "Can not find the standard image at $STD_IMAGE. Please check your FSL installation."
fi

if [ "$ATLAS_TO_USE" ]
then
  STD_ATLAS=
  [ -e "$ATLAS_TO_USE" ] && STD_ATLAS=$ATLAS_TO_USE
  [ -e "$ATLAS_ROOT/$ATLAS_TO_USE" ] && STD_ATLAS=$ATLAS_ROOT/$ATLAS_TO_USE
fi
}

check_fsl()
{
if [ ! $FSLDIR ]
then
  echo_fatal "Can not find FSL installation."
else
  FSLPREFIX=
  for pref in fsl{5.0,4.9}-
  do
    if [ "$(command -v ${pref}fslmaths)" ]
    then
	    FSLPREFIX=$pref
      break
    fi
  done
  for ce in ${FSLPREFIX}{fslmaths,fslstats,fslcpgeom,flirt,fast}
  do
    if [ -z "$(command -v $ce)" ]
    then
      echo_fatal "$ce executable is not available. Please check your FSL installation."
    fi
  done
  FLAIR_OPTIONS_FOR_ATLAS="-interp nearestneighbour"
fi
}

echo_warning()
{
  echo -e "${yellow}WARNING:${normal} $1"
}
echo_error()
{
  echo -e "${red}ERROR:${normal} $1"
}
echo_fatal()
{
  echo -e "${red}FATAL ERROR:${normal} $1"
  exit 1
}

runname()
{
  echo -n "${1}"
  reqcol=$(echo $(tput cols)-${#1}|bc)  
}
rundone()
{
  local OKMSG="[OK] "
  local FAILMSG="[FAIL] "
  [ -n "$2" ] && OKMSG="[$2] "
  [ -n "$3" ] && FAILMSG="[$3] "
  if [ $1 -eq 0 ]
  then
    printf "$green%${reqcol}s$normal\n" "$OKMSG"
  else
    printf "$red%${reqcol}s$normal\n" "$FAILMSG"  
  fi
  return $1
}
runmsg()
{
  echo -n "${1}"
  reqcol=$(echo ${reqcol}-${#1}-1|bc)
}
checkmsg()
{
  runname "$1"
  shift
  eval $1 1>/dev/null 2>/dev/null
  last_res=$?
  shift
  rundone $last_res "$@"
  return $?
}

log_var()
{
  echo "${1}: ${!1}"
}

# Directory structure for the Cascade
temp_dir='cache'
trans_dir='transformations'
images_dir='images'
std_dir='std'
ranges_dir='ranges'
report_dir='report'

OPENING_FlAG="-dilM -ero"
CLOSING_FlAG="-ero -dilM"

set_filenames()
{
         T1_BRAIN=${IMAGEROOT}/${images_dir}/brain_t1.nii.gz
         T2_BRAIN=${IMAGEROOT}/${images_dir}/brain_t2.nii.gz
         PD_BRAIN=${IMAGEROOT}/${images_dir}/brain_pd.nii.gz
      FLAIR_BRAIN=${IMAGEROOT}/${images_dir}/brain_flair.nii.gz
       BRAIN_MASK=${IMAGEROOT}/${images_dir}/brain_mask.nii.gz
         HYP_MASK=${IMAGEROOT}/${images_dir}/heuristic.nii.gz
         
        BRAIN_PVE=${IMAGEROOT}/${images_dir}/TissueType.nii.gz
       BRAIN_WMGM=${IMAGEROOT}/${images_dir}/WhiteMatter+GrayMatter.nii.gz
        BRAIN_CSF=${IMAGEROOT}/${images_dir}/CerebrospinalFluid.nii.gz
         BRAIN_WM=${IMAGEROOT}/${images_dir}/WhiteMatter.nii.gz                
         BRAIN_GM=${IMAGEROOT}/${images_dir}/GrayMatter.nii.gz
    BRAIN_THIN_GM=${IMAGEROOT}/${images_dir}/ThinGrayMatter.nii.gz
                                        
        HYPO_MASK=${IMAGEROOT}/${images_dir}/hypo.nii.gz

            ATLAS=${IMAGEROOT}/${std_dir}/Atlas.nii.gz
           MIDDLE=${IMAGEROOT}/${std_dir}/BrainMask.nii.gz
        MIDDLE_10=${IMAGEROOT}/${std_dir}/BrainMiddleMask10.nii.gz
        MIDDLE_20=${IMAGEROOT}/${std_dir}/BrainMiddleMask20.nii.gz
         OUTER_10=${IMAGEROOT}/${std_dir}/BrainOuterMask10.nii.gz
         OUTER_20=${IMAGEROOT}/${std_dir}/BrainOuterMask20.nii.gz
                                            
FSL_STD_TRANSFORM=${IMAGEROOT}/${trans_dir}/$(fsl_trans_name STD_IMAGE PROC )
ITK_STD_TRANSFORM=${IMAGEROOT}/${trans_dir}/$(itk_trans_name STD_IMAGE PROC )

       LIKELIHOOD=${IMAGEROOT}/${report_dir}/likelihood.nii.gz
      PVALUEIMAGE=${IMAGEROOT}/${report_dir}/pvalue.nii.gz
 PVALUEIMAGE_CONS=${IMAGEROOT}/${report_dir}/pvalue_cons.nii.gz     
          OUTMASK=${IMAGEROOT}/${report_dir}/WMChanges.nii.gz
        REPORTCSV=${IMAGEROOT}/${report_dir}/report.csv
          LOGFILE=${IMAGEROOT}/${report_dir}/error.log
        
     T1_BRAIN_TMP=${IMAGEROOT}/${temp_dir}/brain_t1_tmp.nii.gz
   TRAINMASKIMAGE=${IMAGEROOT}/${temp_dir}/normal_mask.nii.gz
MASK_FOR_HISTOGRAM=${IMAGEROOT}/${temp_dir}/mask_for_histogram.nii.gz
}


# Input 1: Moving
# Input 2: Reference
trans_name()
{
  echo "${1}_to_${2}"
}
# Input 1: Moving
# Input 2: Reference
fsl_trans_name()
{
  echo "$(trans_name ${1} ${2}).mat"
}
# Input 1: Moving
# Input 2: Reference
itk_trans_name()
{
  echo "$(trans_name ${1} ${2}).tfm"
}
# Input 1: Moving
# Input 2: Reference
# input 3: OutDir
# input 4: Matrix
register()
{ 
  if [ $# == 2 ]
  then
    ${FSLPREFIX}flirt ${FLIRT_OPTION} -in ${!1} -ref ${!2} -out ${IMAGEROOT}/${temp_dir}/$(trans_name $1 $2 ) -omat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 ) -dof 12
  elif [ $# == 3 ]
  then
    ${FSLPREFIX}flirt ${FLIRT_OPTION} -in ${!1} -ref ${!2} -out ${IMAGEROOT}/${3}/$(trans_name $1 $2 ) -omat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 ) -dof 21
  elif [ $# == 4 ]
  then
    ${FSLPREFIX}flirt ${FLIRT_OPTION} -in ${!1} -ref ${!2} -out ${IMAGEROOT}/${3}/$(trans_name $1 $2 ) -init ${IMAGEROOT}/${trans_dir}/${4} -applyxfm
  elif [ $# == 5 ]
  then
    ${FSLPREFIX}flirt ${FLIRT_OPTION} -in ${!1} -ref ${!2} -out ${5} -init ${IMAGEROOT}/${trans_dir}/${4} -applyxfm
  fi
  FLIRT_OPTION=
}
# Input 1: Moving
# Input 2: Reference
inverse_transform()
{ 
  ${FSLPREFIX}convert_xfm -omat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $2 $1 ) -inverse ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 )
}
# Input 1: Moving
# Input 2: Reference
do_register()
{
  if [ -s "${!1}" ]
  then
    local TRANSFORM=${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $2 $1 )
    local ITRANSFORM=${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 )
    local REG_IMG=${IMAGEROOT}/${temp_dir}/$(trans_name $2 $1 ).nii.gz
        
	  if [ $REGISTERED == "YES" ]
	  then
	    echo -e "1 0 0 0\n0 1 0 0\n0 0 1 0\n0 0 0 1" >$TRANSFORM
	    cat $TRANSFORM>$ITRANSFORM
      if [ ! -s "$REG_IMG" ]
      then
        register ${2} ${1} ${temp_dir} $(basename $TRANSFORM)
      fi
    elif [ ! -s "$REG_IMG" ]
    then
	    register ${2} ${1}
	    inverse_transform ${2} ${1}
    fi
  fi
}
# Input 1: Moving A
# Input 2: Via B
# Input 3: Reference C
concat_transform()
{ 
  ${FSLPREFIX}convert_xfm -omat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $3 ) -concat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $2 $3 ) ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 )
}
mask()
{
  ${FSLPREFIX}fslmaths ${!1} -mas ${!2} ${!3}
}
trim()
{
  ${FSLPREFIX}fslroi ${1} ${2} $( ${FSLPREFIX}fslstats ${1} -w )
}

range_image()
{
  echo "$IMAGEROOT/$ranges_dir/$(basename $1)"
}


sequence_name()
{
  sed s'/brain_//g' <<< "$(basename $1 .nii.gz)"
}
# Type of WML in each image
sequence_type()
{
  local seq_name=$(sequence_name $1)
  local seq_type="other"
  [[ "${seq_name}" == "t1" ]] && seq_type="dark"
  [[ "${seq_name}" == "t2" ]] && seq_type="light"
  [[ "${seq_name}" == "flair" ]] && seq_type="light"
  [[ "${seq_name}" == "pd" ]] && seq_type="light"
  echo $seq_type
}

# Type of WML in each image
tissue_name()
{
  local name="Other"
  [[ "$1" == "1" ]] && name="Cerebrospinal Fluid"
  [[ "$1" == "2" ]] && name="Gray Matter"
  [[ "$1" == "3" ]] && name="White Matter"
  echo $name
}

sequence_weight()
{
  local seq_name=$(sequence_name $1)
  local seq_weight="1"
  [[ "${seq_name}" == "t1" ]] && seq_weight="0.8"
  [[ "${seq_name}" == "t2" ]] && seq_weight="1"
  [[ "${seq_name}" == "flair" ]] && seq_weight="1.5"
  [[ "${seq_name}" == "pd" ]] && seq_weight="0.5"
  echo $seq_weight
}

total_weight()
{
  export -f sequence_weight sequence_name
  if [ "$ALL_IMAGES" ]
  then
    xargs -n 1 -d ' ' -I {} bash -c 'sequence_weight "$@"' _ {}  <<< $ALL_IMAGES | paste -sd+ | bc -l
  else
    echo 0
  fi
}

get_atlas_label()
{
  max_index=$(${FSLPREFIX}fslstats $1 -R|cut -d ' ' -f2| sed 's/.0*$//g')
  out_label=("NONE" $(printf "Label_%d\n" $( eval echo {1..$max_index} )))
  
  name_file=$(sed 's/.nii.gz$/.labels/g' <<<"$1")
  if [ -s "$name_file" ]
  then
    tmp_label=("NONE" $(cat $name_file | tr ' ' '-'))
		for i in "${!tmp_label[@]}"; do 
		  out_label[$i]="${tmp_label[$i]}"
		done
  fi
  printf -- '%s\n' "${out_label[@]}"
}



