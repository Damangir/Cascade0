#! /bin/bash

$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/run_cascade_main.sh "${@}"
$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/run_cascade_post.sh "${@}"
$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/run_cascade_report.sh "${@}"
$(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/run_cascade_html.sh "${@}"
