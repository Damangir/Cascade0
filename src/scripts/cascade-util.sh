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

copyright()
{
cat << EOF
The Cascade pipeline. github.com/Damangir/Cascade
Copyright (C) 2013 Soheil Damangir - All Rights Reserved

EOF
}

licence()
{
cat << EOF
You may use and distribute, but not modify this code under the terms of the
Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
under the following conditions:
Attribution — You must attribute the work in the manner specified by the
author or licensor (but not in any way that suggests that they endorse you
or your use of the work).
Noncommercial — You may not use this work for commercial purposes.
No Derivative Works — You may not alter, transform, or build upon this
work

To view a copy of the license, visit
http://creativecommons.org/licenses/by-nc-nd/3.0/

EOF
}

echo_warning()
{
  echo -e "${yellow}WARNING:${normal} $1"
}
echo_error()
{
  echo -e "${red}ERROR:${normal} $1"
}
echo_fatal()
{
  echo -e "${red}FATAL ERROR:${normal} $1"
  exit 1
}

runname()
{
  echo -n "${1}"
  reqcol=$(echo $(tput cols)-${#1}|bc)
}
rundone()
{
  local OKMSG="[OK] "
  local FAILMSG="[FAIL] "
  [ -n "$2" ] && OKMSG="[$2] "
  [ -n "$3" ] && FAILMSG="[$3] "
  if [ $1 -eq 0 ]
  then
    printf "$green%${reqcol}s$normal\n" "$OKMSG"
  else
    printf "$red%${reqcol}s$normal\n" "$FAILMSG"  
  fi
  return $1
}
checkmsg()
{
  runname "$1"
  shift
  eval $1 1>/dev/null 2>/dev/null
  last_res=$?
  shift
  rundone $last_res "$@"
  return $?
}

# check if stdout is a terminal...
if [ -t 1 ]; then
  # see if it supports colors...
  ncolors=$(tput colors)
  if test -n "$ncolors" && test $ncolors -ge 8; then
    bold="$(tput bold)"
    underline="$(tput smul)"
    standout="$(tput smso)"
    normal="$(tput sgr0)"
    black="$(tput setaf 0)"
    red="$(tput setaf 1)"
    green="$(tput setaf 2)"
    yellow="$(tput setaf 3)"
    blue="$(tput setaf 4)"
    magenta="$(tput setaf 5)"
    cyan="$(tput setaf 6)"
    white="$(tput setaf 7)"
  fi
fi