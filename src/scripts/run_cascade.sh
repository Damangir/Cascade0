#! /bin/bash

$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/run_cascade_pre.sh "${@}"
$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/run_cascade_train.sh "${@}"
$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/run_cascade_process.sh "${@}"