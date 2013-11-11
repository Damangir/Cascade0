## Project directory structure
PRJHOME=
PRJORIGINAL=${PRJHOME}/Original
PRJCASCADE=${PRJHOME}/Cascade

## Filename patterns
PRJSUBJPATTERN="*"
PRJT1PATTERN=
PRJT2PATTERN=
PRJPDPATTERN=
PRJFLAIRPATTERN=
PRJBRAINMASKPATTERN=

# Brain mask native space Can be either T1, T2, FLAIR or PD
PRJBRAINMASKSPACE="T1"

STATE_PREFIX="${PRJCASCADE}/state"
## Reporting values
CONF=1
## In cubic millimeter
MINSIZE=200
RESULT=${PRJHOME}/Cascade/results_${CONF}.csv

## PARAMETER EXTRACTION
NBIN=100
PERCENTILE=98

## Cascade location
CASCADEDIR=/home/soheil/workspace/Cascade/src/scripts

ORIG_DIR=$(pwd)
trap "cd ${ORIG_DIR}" EXIT