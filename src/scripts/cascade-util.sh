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
# Ensure all directories is there
  mkdir -p ${IMAGEROOT}/{${temp_dir},${trans_dir},${images_dir},${ranges_dir},${report_dir}}

         T1_BRAIN=${IMAGEROOT}/${images_dir}/brain_t1.nii.gz
         T2_BRAIN=${IMAGEROOT}/${images_dir}/brain_t2.nii.gz
         PD_BRAIN=${IMAGEROOT}/${images_dir}/brain_pd.nii.gz
      FLAIR_BRAIN=${IMAGEROOT}/${images_dir}/brain_flair.nii.gz
       BRAIN_MASK=${IMAGEROOT}/${images_dir}/brain_mask.nii.gz
         HYP_MASK=${IMAGEROOT}/${images_dir}/heuristic.nii.gz
      NORMAL_MASK=${IMAGEROOT}/${images_dir}/normal.nii.gz         

        BRAIN_PVE=${IMAGEROOT}/${images_dir}/TissueType.nii.gz
       BRAIN_WMGM=${IMAGEROOT}/${images_dir}/WhiteMatter+GrayMatter.nii.gz
        BRAIN_CSF=${IMAGEROOT}/${images_dir}/CerebrospinalFluid.nii.gz
         BRAIN_WM=${IMAGEROOT}/${images_dir}/WhiteMatter.nii.gz                
         BRAIN_GM=${IMAGEROOT}/${images_dir}/GrayMatter.nii.gz

          Z_SCORE=${IMAGEROOT}/${temp_dir}/z-score.nii.gz
                                        
            ATLAS=${IMAGEROOT}/${std_dir}/Atlas.nii.gz
                                            
FSL_STD_TRANSFORM=${IMAGEROOT}/${trans_dir}/$(fsl_trans_name STD_IMAGE PROC )
ITK_STD_TRANSFORM=${IMAGEROOT}/${trans_dir}/$(itk_trans_name STD_IMAGE PROC )

       LIKELIHOOD=${IMAGEROOT}/${report_dir}/likelihood.nii.gz
      PVALUEIMAGE=${IMAGEROOT}/${report_dir}/pvalue.nii.gz
          OUTMASK=${IMAGEROOT}/${report_dir}/WMChanges.nii.gz

        REPORTCSV=${IMAGEROOT}/${report_dir}/report.csv
       REPORTHTML=${IMAGEROOT}/${report_dir}/report.html
      OVERVIEWIMG=${IMAGEROOT}/${report_dir}/overview.png
        
     T1_BRAIN_TMP=${IMAGEROOT}/${temp_dir}/brain_t1_tmp.nii.gz
   TRAINMASKIMAGE=${IMAGEROOT}/${temp_dir}/normal_mask.nii.gz
         SUBJECTID=$(basename $IMAGEROOT)
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
nonlinear_trans_name()
{
  echo "$(trans_name ${1} ${2})_NL.nii.gz"
}
# Input 1: Moving
# Input 2: Reference
# input 3: OutDir
# input 4: Matrix
register()
{ 
  if [ $# == 2 ]
  then
    ${FSLPREFIX}flirt ${FLIRT_OPTION} -in ${!1} -ref ${!2} -out ${SAFE_TMP_DIR}/$(trans_name $1 $2 ) -omat ${IMAGEROOT}/${trans_dir}/$(fsl_trans_name $1 $2 ) -dof 12
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

    local REG_IMG=${SAFE_TMP_DIR}/$(trans_name $2 $1 ).nii.gz
    local REG_IMG_INVERSE=${SAFE_TMP_DIR}/$(trans_name $1 $2 ).nii.gz
                
	  if [ $REGISTERED == "YES" ]
	  then
	    echo -e "1 0 0 0\n0 1 0 0\n0 0 1 0\n0 0 0 1" >$TRANSFORM
	    cat $TRANSFORM>$ITRANSFORM
      if [ ! -s "$REG_IMG" ]
      then
        register ${2} ${1} - $(basename $TRANSFORM) $REG_IMG
      fi
    elif [ ! -s "$REG_IMG" ]
    then
	    register ${2} ${1}
	    inverse_transform ${2} ${1}
    fi
    
    if [ ! -s "$REG_IMG_INVERSE" ]
    then
      register ${1} ${2} - $(basename $ITRANSFORM) $REG_IMG_INVERSE
    fi
    
    echo $REG_IMG_INVERSE
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

range_image()
{
  echo "$IMAGEROOT/$ranges_dir/$(basename $1)"
}

std_image()
{
  echo "$IMAGEROOT/$std_dir/$(basename $1)"
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
  [[ "$1" == "4" ]] && name="White Matter + Gray Matter"
  echo $name
}
