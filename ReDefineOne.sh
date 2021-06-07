#!/bin/bash

set -e

if [[  ! -f "$1" ]]; then
   echo "[ERROR] File <$1> does not exists"
   exit 1
fi

zip=$1
dir=${zip%.*}
log=ReDefineZip.log
base=$(basename $zip)

echo "${base%.*}"                    >  $log
echo "${base%.*}" | sed -e 's!.!-!g' >> $log

{ time ./ReDefineZip.sh --int2ssl=Tools/int2ssl --redefine=Tools/ReDefine --mod=$zip ; } 2>>$log

if [[ -d $dir ]]; then
   echo                  >> $log
   du -hd0 $dir          >> $log
   du -hd0 $dir/Original >> $log
   du -hd0 $dir/ReDefine >> $log
fi
echo
cat $log
echo
