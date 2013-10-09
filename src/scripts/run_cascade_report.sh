#! /bin/bash

source $(dirname $0)/project_setting.sh

>$RESULT

for f in $(find ${PRJCASCADE} -maxdepth 1 -name ${PRJSUBJPATTERN} | sort)
do
  id=$(basename $f)
  echo Processing $id
  ${CASCADEDIR}/cascade-report.sh -c $CONF -p $MINSIZE -r ${f}

  if ! [ -s $RESULT ]
  then
    cat ${f}/report/report.csv >> $RESULT
  else
    tail -n+2 ${f}/report/report.csv >> $RESULT
  fi
done
