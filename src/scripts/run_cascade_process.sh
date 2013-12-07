#! /bin/bash

$(dirname $0)/run_cascade_main.sh "${@}"
$(dirname $0)/run_cascade_post.sh "${@}"
$(dirname $0)/run_cascade_report.sh "${@}"
$(dirname $0)/run_cascade_html.sh "${@}"
