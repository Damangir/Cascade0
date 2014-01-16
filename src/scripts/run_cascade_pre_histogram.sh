#! /bin/bash

[ -z "$PRJHOME" ] && [ -f "$1" ] && PRJSETTINGS="$1"
[ -z "$PRJHOME" ] && [ -d "$1" ] && [ -f "${1}/project_setting.sh" ] && PRJSETTINGS="${1}/project_setting.sh"
[ -z "$PRJHOME" ] && [ -f "./project_setting.sh" ] && PRJSETTINGS="./project_setting.sh"

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh

[ -z "$PRJHOME" ] && echo "No proper settings. Are you sure you have a proper project_setting.sh file?" >&2 && exit 1

if ! [ "$(dirname ${HIST_ROOT})" -ef "${CASCADEDATA}" ]
then
TMPHIST=$(mktemp -u --suffix .hist)
trap "rm ${TMPHIST}" EXIT
histograms=$(ls ${PRJCASCADE}/${PRJSUBJPATTERN}/transformations/*.hist 2>/dev/null | xargs -n 1 basename |sort | uniq)
for hist in $histograms
do 
  normal_histogram=${HIST_ROOT}/$hist
  ## Run an awk to average histograms
	awk '
	NR==FNR{
	  if (max_nf < NF)
	    max_nf = NF
	  if (max_nr < FNR)
	    max_nr = FNR
	
	  for (j = 1; j <= NF; j++)
	    a[FNR-1,j-1]=$j
	  next
	}
	{
	  if (max_nf < NF)
	    max_nf = NF
	  if (max_nr < FNR)
	    max_nr = FNR
	
	  for (j = 1; j <= NF; j++)
	    a[FNR-1,j-1]+=$j
	}
	END{
	  num_files=NR/FNR
	  for (x = 0; x < max_nr; x++)
	  {
	     printf("%d ", a[x, 0]/num_files)
	     printf("%.3f ", a[x, 1]/num_files)
	     for (y = 2; y < max_nf; y++)
	          printf("%.10f ", a[x, y]/num_files)
	     printf("\n")
	  }
	}' ${PRJCASCADE}/${PRJSUBJPATTERN}/transformations/${hist} >${normal_histogram}

	TRG_INTENSITY=($(cut -d ' ' -f1 ${normal_histogram}))
	TRG_PERCENTILE=($(cut -d ' ' -f4 ${normal_histogram}))
	
	PERC=0.75
	j=0
	while true
	do
	  PERC_LO=${TRG_PERCENTILE[$j]}
	  PERC_HI=${TRG_PERCENTILE[$(( $j + 1 ))]}
	  [ $PERC_LO ] && [ $PERC_HI ] && LAST_PERC=$(bc -l <<< "$PERC_HI + $PERC_HI - $PERC_LO")
	        
	  INT_LO=${TRG_INTENSITY[$j]}
	  INT_HI=${TRG_INTENSITY[$(( $j + 1 ))]}
	  [ $INT_LO ] && [ $INT_HI ] && LAST_INT=$(bc -l <<< "$INT_HI + $INT_HI - $INT_LO")
	
	  [ -z $INT_LO ] && INT_LO=$LAST_INT
	  [ -z $INT_HI ] && INT_HI=$LAST_INT
	            
	  [ -z $PERC_LO ] && PERC_LO=$LAST_PERC 
	  [ -z $PERC_HI ] && PERC_HI=$LAST_PERC
	    
	  [ $(bc <<< "$PERC <= $PERC_HI") -eq 1 ] && break
	  j=$(( $j + 1 ))
	done
	
	if [ $(bc <<< "$PERC_LO == $PERC_HI") -eq 1 ]
	then
	  INTERPOLATION="( $INT_HI - $INT_LO )/2"  
	else 
	  INTERPOLATION="( $INT_HI - $INT_LO )/( $PERC_HI - $PERC_LO ) * ( $PERC - $PERC_LO ) + $INT_LO"
	fi  
	
	ONE_INT=$(bc -l <<< "a=$INTERPOLATION;if(a>0) a else 0" ) 
  awk -v one_int=$ONE_INT '{printf("%f", $1 / one_int);for (j = 2; j <= NF; j++) printf(" %.10f",$j);printf("\n")}' ${normal_histogram} > $TMPHIST && mv $TMPHIST ${normal_histogram}
	
done
fi

COMMANDS=
for hist in $(ls ${PRJCASCADE}/${PRJSUBJPATTERN}/transformations/*.hist 2>/dev/null)
do
  normal_histogram=${HIST_ROOT}/$(basename $hist)
  transform=$(sed 's/.hist$/.trans/g' <<<"$hist")
  COMMANDS="${COMMANDS}\n$hist $normal_histogram $transform"
done

echo -e $COMMANDS | xargs -n 3 -P $(( $NUMCPU - 1 ))  ${CASCADESCRIPT}/cascade-histogram-match.sh
