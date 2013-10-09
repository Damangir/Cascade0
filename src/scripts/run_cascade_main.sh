#! /bin/bash

source $(dirname $0)/project_setting.sh

for f in $(find ${PRJCASCADE} -maxdepth 1 -name ${PRJSUBJPATTERN} | sort)
do
id=$(basename $f)
echo Processing $id
${CASCADEDIR}/cascade-main.sh -r ${f} -s ${PRJCASCADE}/state

done
