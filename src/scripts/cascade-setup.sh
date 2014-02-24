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

RESET_XTRACE=$(set +o | grep xtrace)
set +o xtrace

cascade_copyright()
{
[ -z "$MUTE_COPYRIGHT" ] && cat << EOF

The Cascade pipeline. github.com/Damangir/Cascade
Copyright (C) 2013 Soheil Damangir - All Rights Reserved

EOF
}

cascade_license()
{
cat << EOF
You may use and distribute, but not modify this code under the terms of the Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License under the following conditions:
Attribution — You must attribute the work in the manner specified by the author or licensor (but not in any way that suggests that they endorse you or your use of the work).
Noncommercial — You may not use this work for commercial purposes.
No Derivative Works — You may not alter, transform, or build upon this work

To view a copy of the license, visit:
http://creativecommons.org/licenses/by-nc-nd/3.0/

EOF
}

DIR="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )"

export NUMCPU=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)
export CASCADESCRIPT=$DIR

if [ -x ${DIR}/cascade-range  ]
then
CASCADEDIR=${DIR}
CASCADEDATA=${DIR}/../data
else
CASCADEDIR=${DIR}/../../build
CASCADEDATA=${DIR}/../../data
fi

export CASCADEDIR
export CASCADEDATA

export HIST_ROOT=${CASCADEDATA}/histograms
export ATLAS_ROOT=${CASCADEDATA}/atlas
export STANDARD_ROOT=$CASCADEDATA/standard
export MASK_ROOT=$CASCADEDATA/mask
export REPORT_ROOT=$CASCADEDATA/report
export CONFIG_ROOT=$CASCADEDATA/config

if [ -s "$PRJSETTINGS" ]
then
  echo "Loading project setting from:"
  echo $(cd $(dirname "$PRJSETTINGS") && pwd -P )/$(basename "$PRJSETTINGS")
  
  source $PRJSETTINGS
  [ -z "$PRJHOME" ] && echo "PRJHOME not set. Please double check your project setting. Current setting is: $PRJSETTINGS" >&2 && exit 1
  
  [ -z "$PRJNAME" ] && PRJNAME=$(basename "$PRJHOME")
  [ -z "$PRJORIGINAL" ] && PRJORIGINAL=${PRJHOME}/Original
  [ -z "$PRJCASCADE" ] && PRJCASCADE=${PRJHOME}/Cascade
  [ -z "$PRJRESULTS" ] && PRJRESULTS=${PRJHOME}/Results
  
	[ -z "$CONF" ] && CONF=0.925
	[ -z "$MINSIZE" ] && MINSIZE=200
	[ -z "$STATE_PREFIX" ] && STATE_PREFIX="${PRJCASCADE}/state"
	[ -z "$RESULT" ] && RESULT=${PRJRESULTS}/results_${CONF}.csv
	[ -z "$PRJREPORTHTML" ] && PRJREPORTHTML=${PRJRESULTS}/results_${CONF}.html
	[ -z "$NBIN" ] && NBIN=100
	[ -z "$PERCENTILE" ] && PERCENTILE=98
	[ -z "$PARALLEL" ] && PARALLEL=$NUMCPU
  
	export ATLAS_TO_USE
	export NON_LINEAR

	mkdir -p "$PRJORIGINAL" "$PRJCASCADE" "$PRJRESULTS"
	
	ORIG_DIR=$(pwd)
	trap "cd ${ORIG_DIR}" EXIT

  export MUTE_COPYRIGHT
  [ "$MUTE_COPYRIGHT" ] &&  ( MUTE_COPYRIGHT=; cascade_copyright;cascade_license )	
fi 

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

SAFE_TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'cascade_tmp')
trap "rm -rf ${SAFE_TMP_DIR}" EXIT

check_cascade()
{
for ce in {cascade-{range,property-filter}}
do
  if [ ! -x $CASCADEDIR/$ce ]
  then
    echo_fatal "Cascade executable ${underline}${ce}${normal} is not available. Please check your Cascade installation."
  fi
done

STD_IMAGE=$STANDARD_ROOT/MNI152_T1_1mm_brain.nii.gz

if [ ! -f "$STD_IMAGE" ]
then
  echo_fatal "Can not find the standard image at "$STD_IMAGE". Please check your Cascade installation."
fi

if [ "$ATLAS_TO_USE" ]
then
  STD_ATLAS=
  [ -e "$ATLAS_TO_USE" ] && STD_ATLAS="$ATLAS_TO_USE"
  [ -e "${ATLAS_ROOT}/$ATLAS_TO_USE" ] && STD_ATLAS=${ATLAS_ROOT}/$ATLAS_TO_USE
fi

}

check_fsl()
{
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
FLIRT_OPTIONS_FOR_ATLAS="-interp nearestneighbour"
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
  printf "${1}"
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

check_fsl
check_cascade

source ${CASCADESCRIPT}/cascade-util.sh

$RESET_XTRACE
