#! /bin/bash


$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/run_cascade_pre1.sh "${@}"
$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/run_cascade_pre2.sh "${@}"
