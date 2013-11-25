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


SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]
do 
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

export NUMCPU=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)

export CASCADESCRIPT=$DIR
export CASCADEDIR=${DIR}/../../build
export CASCADEDATA=${DIR}/../../data

export HIST_ROOT=${CASCADEDATA}/histograms
export ATLAS_ROOT=${CASCADEDATA}/atlas
export STANDARD_ROOT=$CASCADEDATA/standard
export MASK_ROOT=$CASCADEDATA/mask
export REPORT_ROOT=$CASCADEDATA/report

if [ -s "$PRJSETTINGS" ]
then
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
	
	mkdir -p "$PRJORIGINAL" "$PRJCASCADE" "$PRJRESULTS"
	ORIG_DIR=$(pwd)
	trap "cd ${ORIG_DIR}" EXIT

  export MUTE_COPYRIGHT
  [ "$MUTE_COPYRIGHT" ] &&  ( MUTE_COPYRIGHT=; cascade_copyright;cascade_license )
	
fi 

if ! [ "$(command -v ${FSLPREFIX}fslmaths)" ]
then
	for pref in fsl{5.0,4.9}-
	do
		if [ "$(command -v ${pref}fslmaths)" ]
		then
			FSLPREFIX=$pref
			break
		fi
	done
fi

source ${DIR}/cascade-util.sh

check_fsl
check_cascade