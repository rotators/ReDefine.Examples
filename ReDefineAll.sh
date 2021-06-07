#!/bin/bash

set -e

find . -type f -iname '*.zip' | sort | while read zip; do
    ./ReDefineOne.sh ${zip//\.\//}
done
