#! /bin/bash

$(dirname $0)/run_cascade_pre.sh "${@}"
$(dirname $0)/run_cascade_train.sh "${@}"
$(dirname $0)/run_cascade_main.sh "${@}"
$(dirname $0)/run_cascade_report.sh "${@}"
