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
${bold}usage${normal}: $0

This script checks if the Cascade and its dependencies is properly configured
  
EOF
}

source $(cd $(dirname "${BASH_SOURCE[0]}") && pwd -P )/cascade-setup.sh
cascade_copyright

runname "Checking Cascade installation"
check_cascade
rundone $? || exit 1
runname "Checking Required FSL functionalities"
check_fsl
rundone $? || exit 1

echo
echo "Cascade configured correctly. Congratulations!"