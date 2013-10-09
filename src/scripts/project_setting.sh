## Project directory structure
PRJHOME=/home/soheil/Projects/Erik_Gothenburg
PRJORIGINAL=${PRJHOME}/Original
PRJCASCADE=${PRJHOME}/Cascade

## Filename patterns
PRJSUBJPATTERN="*"
PRJT1PATTERN="*T1*"
PRJT1MASKPATTERN="*brainmask*"
PRJFLAIRPATTERN="*FLAIR*"

## Reporting values
CONF=1
## In cubix millimeter
MINSIZE=200
RESULT=${PRJHOME}/Cascade/results_${CONF}.csv

## Cascade location
CASCADEDIR=/home/soheil/workspace/Cascade/src/scripts

ORIG_DIR=$(pwd)
trap "cd ${ORIG_DIR}" EXIT
