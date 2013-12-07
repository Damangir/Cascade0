#! /bin/bash
#  Copyright (C) 2013 Soheil Damangir - All Rights Reserved
#  You may use and distribute, but not modify this code under the terms of the
#  Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
#  under the following conditions:
#
#  Attribution — You must attribute the work in the manner specified by the
#  author or licensor (but not in any way that suggests that they endorse you
#  or your use of the work).
#  Noncommercial — You may not use this work for commercial purposes.
#  No Derivative Works — You may not alter, transform, or build upon this
#  work
#
#  To view a copy of the license, visit
#  http://creativecommons.org/licenses/by-nc-nd/3.0/
#  

[ -z "$PRJHOME" ] && [ -f "$1" ] && PRJSETTINGS="$1"
[ -z "$PRJHOME" ] && [ -d "$1" ] && [ -f "${1}/project_setting.sh" ] && PRJSETTINGS="${1}/project_setting.sh"
[ -z "$PRJHOME" ] && [ -f "./project_setting.sh" ] && PRJSETTINGS="./project_setting.sh"

source $(dirname $0)/cascade-setup.sh

[ -z "$PRJHOME" ] && echo "No proper settings. Are you sure you have a proper project_setting.sh file?" >&2 && exit 1

for f in $(find "${PRJCASCADE}" -maxdepth 1 -name "${PRJSUBJPATTERN}" | sort)
do
  id=$(basename $f)
  echo -e "${header_format}Processing ${id}${normal}"
  ${CASCADESCRIPT}/cascade-html.sh -r ${f}
  mkdir -p $(dirname $PRJREPORTHTML)/${id}
  ln -s ${f}/${report_dir} $(dirname $PRJREPORTHTML)/${id}/report
done

(
cat $REPORT_ROOT/report_head.html
cat << EOF
<header> <!-- Defining the header section of the page with the appropriate tag -->
    <hgroup>
        <h1>Cascade</h1>
        <h3>Segmentation of white matter lesions</h3>
    </hgroup>
    <nav class="clear"> <!-- The nav link semantically marks your main site navigation -->
        <ul>
            <li><a href="#article1">Overview for $PRJNAME</a></li>
        </ul>
    </nav>
</header>
           
 <section id="articles"> <!-- A new section with the articles -->
  <!-- Article 1 start -->
  <div class="line"></div>  <!-- Dividing line -->

  <article id="article1"> <!-- The new article tag. The id is supplied so it can be scrolled into view. -->
  <h2>Overview for $PRJNAME</h2>
  <div class="line"></div>
  <div class="articleBody clear">
  <div class="results">
EOF

awk -v header=yes -f $(dirname $0)/cascade-results-html.awk $RESULT

cat << EOF
  </div>
  
  </div>
  </article>
  <!-- Article 1 end -->
</section>
EOF

cat $REPORT_ROOT/report_tail.html
) > $PRJREPORTHTML