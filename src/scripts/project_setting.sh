## Project directory structure
PRJHOME=
PRJORIGINAL=${PRJHOME}/Original
PRJCASCADE=${PRJHOME}/Cascade

## Filename patterns.
##  Be sure to include asterisk sign (wildcard) in the patterrns.
PRJSUBJPATTERN="*"
PRJT1PATTERN="*T1*"
PRJT2PATTERN="*T2*"
PRJPDPATTERN="*PD*"
PRJFLAIRPATTERN="*flair*"
PRJBRAINMASKPATTERN="*brain_mask*"

## Brain mask native space Can be either T1, T2, FLAIR, PD or NONE
## None means that the images are already brain extracted.
PRJBRAINMASKSPACE="NONE"

#ATLAS_TO_USE="MNI152_1mm_ATLAS.nii.gz"

STATE_PREFIX="${PRJCASCADE}/state"
## Reporting values
CONF=0.925
## In cubic millimeter
MINSIZE=200
RESULT=${PRJCASCADE}/results_${CONF}.csv

## PARAMETER EXTRACTION
NBIN=100
PERCENTILE=98

ORIG_DIR=$(pwd)
trap "cd ${ORIG_DIR}" EXIT