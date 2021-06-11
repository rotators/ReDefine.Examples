#!/bin/bash

set -e

if [[  ! -d "$1" ]]; then
   echo "[ERROR] Directory <$1> does not exists"
   exit 1
fi

dir="$1"

find "$(echo "$dir" | sed -re 's![/]+$!/!')" -type f -iname '*.zip' | sort | while read zip; do
    ./ReDefineOne.sh ${zip//\.\//}
done
