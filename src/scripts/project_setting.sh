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

## Reporting values
CONF=1
## In cubic millimeter
MINSIZE=200
RESULT=${PRJHOME}/Cascade/results_${CONF}.csv

## Cascade location
CASCADEDIR=/home/soheil/workspace/Cascade/src/scripts

ORIG_DIR=$(pwd)
trap "cd ${ORIG_DIR}" EXIT