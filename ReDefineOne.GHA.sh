#!/bin/bash

set -eu

if (( $# >= 1 )); then
   zip="$1"
   dir="${zip%.*}/"
else
   echo "[ERROR] File name missing"
   exit 1
fi

if [[ ! -f "$zip" ]]; then
   echo "[WARNING] File <$zip> does not exists"
   exit
fi

ok=1
./ReDefineOne.sh "${zip//\.\//}" || ok=0

if [[ $ok -eq 0 ]]; then
   echo "[WARNING] ReDefine script error"
   if [[ -d "$dir" ]]; then
      echo "[WARNING] Directory <$dir> reset"
      git checkout -- "$dir"
   fi
   exit
fi

if [[ ! -d "$dir" ]]; then
   echo "[WARNING] Directory <$dir> does not exists"
   exit
fi

if [[ -z "${GHA_COMMIT+x}"2 ]]; then
   gha="ReDefine.GHA.txt"
   echo "[WARNING] GHA_COMMIT variable missing"
   echo "[WARNING] Using default value <$gha>"
else
   gha="$GHA_COMMIT"
fi

echo
if [[ -n "$(git status --short --untracked-files=all "$dir")" ]]; then
   git add "$dir"
   echo "$dir : updated"
   echo "- Updated $dir" >> $gha
else
   echo "$dir : no changes"
fi
