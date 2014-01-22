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

usage()
{
cat << EOF
${bold}usage${normal}: $0 options

This script creats HTML report for a subject

${bold}OPTIONS$normal:
   -r      Image root directory
   
   -h      Show this message
   -l      Show license
   
EOF
}

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh

while getopts “hr:l” OPTION
do
  case $OPTION in
## Subject directory
    r)
      IMAGEROOT=$OPTARG
      ;;
## Help and license      
    l)
      cascade_copyright
      cascade_license
      exit 1
      ;;
    h)
      usage
      exit 1
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

IMAGEROOT=$(cd "$IMAGEROOT" && pwd -P )     
if [ ! -d "${IMAGEROOT}" ]
then
  echo_fatal "IMAGEROOT is not a directory."
fi

set_filenames

runname "Creating HTML report"
(
(
if ! [ -s "$OVERVIEWIMG" ]
then
	images_to_overlay=$(ls ${IMAGEROOT}/${images_dir}/brain_{flair,t2,t1,pd}.nii.gz 2>/dev/null | head -n 1)
  cp $(do_overlay $images_to_overlay) "$OVERVIEWIMG"
fi

cat $REPORT_ROOT/report_head.html 

cat << EOF
<header> <!-- Defining the header section of the page with the appropriate tag -->
    <hgroup>
        <h1>Cascade</h1>
        <h3>Segmentation of white matter lesions</h3>
    </hgroup>
    <nav class="clear"> <!-- The nav link semantically marks your main site navigation -->
        <ul>
            <li><a href="#article1">Overview for $SUBJECTID</a></li>
        </ul>
    </nav>
</header>
           
 <section id="articles"> <!-- A new section with the articles -->
  <!-- Article 1 start -->
  <div class="line"></div>  <!-- Dividing line -->

  <article id="article1"> <!-- The new article tag. The id is supplied so it can be scrolled into view. -->
  <h2>Overview for $SUBJECTID</h2>
  <div class="line"></div>
  <div class="articleBody clear">
  <div class="results">
EOF

awk -v header=yes -f $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-csv-html.awk $REPORTCSV

cat << EOF
  </div>
  <figure><img src="$(basename $OVERVIEWIMG)" width="100%" /></figure>
  </div>
  </article>
  <!-- Article 1 end -->
</section>
EOF

cat $REPORT_ROOT/report_tail.html
) > $REPORTHTML
if ! [ "$?" -eq 0 ]
then
  rm $REPORTHTML
  exit 1
fi
)
rundone $?