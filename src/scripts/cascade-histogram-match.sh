#! /usr/bin/env bash

SRC_HISTOGRAM=$1
TRG_HISTOGRAM=$2
OUTFILE=${3:-"/dev/stdout"}

SRC_INTENSITY=($(cut -d ' ' -f2 $SRC_HISTOGRAM))
SRC_PERCENTILE=($(cut -d ' ' -f4 $SRC_HISTOGRAM))

TRG_INTENSITY=($(cut -d ' ' -f1 $TRG_HISTOGRAM))
TRG_PERCENTILE=($(cut -d ' ' -f4 $TRG_HISTOGRAM))

j=0
for i in "${!SRC_INTENSITY[@]}"; do 
  FROM_INT=${SRC_INTENSITY[$i]}
  PERC=${SRC_PERCENTILE[$i]}
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
  TO_INT=$(bc -l <<< "a=$INTERPOLATION;if(a>0) a else 0" )
	echo "$PERC $FROM_INT $TO_INT" > $OUTFILE
done