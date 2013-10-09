#! /bin/bash

source $(dirname $0)/project_setting.sh

for f in $(find ${PRJORIGINAL} -maxdepth 1 -name ${PRJSUBJPATTERN} | sort )
do
id=$(basename $f)

    t1=$(find $f -iname $PRJT1PATTERN     | head -n 1)
 flair=$(find $f -iname $PRJFLAIRPATTERN  |head -n 1)
t1mask=$(find $f -iname $PRJT1MASKPATTERN |head -n 1)

if ! [ -s $t1 ] && [ -s $t1mask ] && [ -s $flair ]
then
echo "There is not all needed data for $f"
continue
fi

mkdir -p ${PRJCASCADE}/${id}
${CASCADEDIR}/cascade-pre.sh -r ${PRJCASCADE}/${id} -t $t1 -b $t1mask -f $flair

done
