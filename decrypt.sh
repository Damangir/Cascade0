#! /bin/bash

extensions="h hxx cxx cpp"
read -e -p "Enter the passphrase: " PASS_FIXED


red='\E[31m'
green='\E[32m'
reset='\E[0m'
for e in $extensions
do
  files=`find . -name "*.${e}"`
  for f in $files
  do
    echo -n "Decrypting ${f} "
    cat $f | openssl enc -d -base64 -aes-256-ecb -k $PASS_FIXED 2> /dev/null 1> $f.dec
    if [[ $? -eq 0 ]]
    then
      echo -e "${green}OK${reset}"
      mv $f.dec $f  
    else
      echo -e "${red}Failed${reset}"
      rm $f.dec
    fi
  done
done

