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

copyright()
{
cat << EOF

The Cascade pipeline. github.com/Damangir/Cascade
Copyright (C) 2013 Soheil Damangir - All Rights Reserved

EOF
}

licence()
{
cat << EOF
You may use and distribute, but not modify this code under the terms of the
Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
under the following conditions:
Attribution — You must attribute the work in the manner specified by the
author or licensor (but not in any way that suggests that they endorse you
or your use of the work).
Noncommercial — You may not use this work for commercial purposes.
No Derivative Works — You may not alter, transform, or build upon this
work

To view a copy of the license, visit
http://creativecommons.org/licenses/by-nc-nd/3.0/

EOF
}

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
  fi
fi

check_cascade()
{
for ce in {cascade-{range,train,likelihood,report,inspect,property-filter},c3d_affine_tool}
do
  if [ ! -x $CASCADEDIR/$ce ]
  then
    echo_fatal "Cascade executable ${underline}${ce}${normal} is not available. Please check your Cascade installation."
  fi
done
STDMIDDLEBRAIN=$CASCADEDATA/middle_brain.nii.gz
}

check_fsl()
{
if [ ! $FSLDIR ]
then
  echo_fatal "Can not find FSL installation."
else
  for ce in {fslmaths,flirt,fast}
  do
    if [ ! -x $FSLDIR/bin/$ce ]
    then
      echo_fatal "$ce executable is not available. Please check your FSL installation."
    fi
  done
  STDIMAGE=$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz
  if [ ! -f $STDIMAGE ]
  then
      echo_fatal "Can not find the standard image at $STDIMAGE. Please check your FSL installation."
  fi
  STDATLAS=$FSLDIR/data/atlases/MNI/MNI-maxprob-thr25-1mm.nii.gz
  if [ ! -f $STDATLAS ]
  then
      echo_fatal "Can not find the atlas image at $STDATLAS. Please check your FSL installation."
  fi
    
  if echo "$LD_LIBRARY_PATH" | grep -qv "$FSLDIR/bin"
  then
    OLD_LD="$LD_LIBRARY_PATH"
    trap "LD_LIBRARY_PATH=$OLD_LD" EXIT
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${FSLDIR}/bin 
  fi
  
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
ranges_dir='ranges'
report_dir='report'

OPENING_FlAG="-dilM -ero"
CLOSING_FlAG="-ero -dilM"

set_filenames()
{
         T1_BRAIN=${IMAGEROOT}/${images_dir}/brain_t1.nii.gz
      FLAIR_BRAIN=${IMAGEROOT}/${images_dir}/brain_flair.nii.gz
        BRAIN_PVE=${IMAGEROOT}/${images_dir}/TissueType.nii.gz
       BRAIN_WMGM=${IMAGEROOT}/${images_dir}/WhiteMatter+GrayMatter.nii.gz
        BRAIN_CSF=${IMAGEROOT}/${images_dir}/CerebrospinalFluid.nii.gz
         BRAIN_WM=${IMAGEROOT}/${images_dir}/WhiteMatter.nii.gz                
         BRAIN_GM=${IMAGEROOT}/${images_dir}/GrayMatter.nii.gz
    BRAIN_THIN_GM=${IMAGEROOT}/${images_dir}/ThinGrayMatter.nii.gz
                                        
        HYPO_MASK=${IMAGEROOT}/${images_dir}/hypo.nii.gz
       PROC_ATLAS=${IMAGEROOT}/${images_dir}/Atlas.nii.gz

FSL_STD_TRANSFORM=${IMAGEROOT}/${trans_dir}/$(fsl_trans_name PROC STDIMAGE )
ITK_STD_TRANSFORM=${IMAGEROOT}/${trans_dir}/$(itk_trans_name PROC STDIMAGE )

       LIKELIHOOD=${IMAGEROOT}/${report_dir}/likelihood.nii.gz
      PVALUEIMAGE=${IMAGEROOT}/${report_dir}/pvalue.nii.gz
 PVALUEIMAGE_CONS=${IMAGEROOT}/${report_dir}/pvalue_cons.nii.gz     
          OUTMASK=${IMAGEROOT}/${report_dir}/WMChanges.nii.gz
        REPORTCSV=${IMAGEROOT}/${report_dir}/report.csv
          LOGFILE=${IMAGEROOT}/${report_dir}/error.log
        
     T1_BRAIN_TMP=${IMAGEROOT}/${temp_dir}/brain_t1_tmp.nii.gz
   TRAINMASKIMAGE=${IMAGEROOT}/${temp_dir}/normal_mask.nii.gz
       BRAIN_MASK=${IMAGEROOT}/${temp_dir}/$(trans_name T1_BRAIN_MASK FLAIR).nii.gz
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
    flirt ${FLIRT_OPTION} -in ${!1} -ref ${!2} -out ${IMAGEROOT}/${temp_dir}/$(trans_name $1 $2 ) -omat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 ) -dof 12
  elif [ $# == 3 ]
  then
    flirt ${FLIRT_OPTION} -in ${!1} -ref ${!2} -out ${IMAGEROOT}/${3}/$(trans_name $1 $2 ) -omat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 ) -dof 21
  elif [ $# == 4 ]
  then
    flirt ${FLIRT_OPTION} -in ${!1} -ref ${!2} -out ${IMAGEROOT}/${3}/$(trans_name $1 $2 ) -init ${IMAGEROOT}/${trans_dir}/${4} -applyxfm
  elif [ $# == 5 ]
  then
    flirt ${FLIRT_OPTION} -in ${!1} -ref ${!2} -out ${5} -init ${IMAGEROOT}/${trans_dir}/${4} -applyxfm
  fi
  FLIRT_OPTION=
}
# Input 1: Moving
# Input 2: Reference
inverse_transform()
{ 
  convert_xfm -omat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $2 $1 ) -inverse ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 )
}
# Input 1: Moving A
# Input 2: Via B
# Input 3: Reference C
concat_transform()
{ 
  convert_xfm -omat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $3 ) -concat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $2 $3 ) ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 )
}
mask()
{
  fslmaths ${!1} -mas ${!2} ${!3}
}

range_image()
{
  echo "$IMAGEROOT/$ranges_dir/$(basename $1)"
}

# Type of WML in each image
sequence_type()
{
  if [[ "$(basename $1)" == *t1* ]]
  then
    echo "dark"
  elif [[ "$(basename $1)" == *t2* ]]
  then
    echo "light"
  elif [[ "$(basename $1)" == *flair* ]]
  then
    echo "light"
  else
    echo "light"
  fi
}