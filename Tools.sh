#!/bin/bash

set -eu

function GetToolCMake()
{
    local name=$1
    local repo=$2
    local src=$3

    local dir=Tools/$name.work

    rm -fr $dir
    git clone $repo $dir/Repo
    cmake -S $dir/Repo/$src -B $dir/Build
    cmake --build $dir/Build --config Release
    cp $dir/Build/$name Tools/$name
    rm -fr $dir
}

function GetToolRaw()
{
    local name=$1
    local repo=$2
    local src=$3

    local dir=Tools/$name.work

    rm -fr $dir
    git clone $repo $dir/Repo
    cp $dir/Repo/$src Tools/$name
    rm -fr $dir
}

if [ ! -f Tools/int2ssl ]; then
   GetToolCMake int2ssl https://github.com/FakelsHub/int-sslc int2ssl
fi

if [ ! -f Tools/ReDefine ]; then
   GetToolCMake ReDefine https://github.com/rotators/ReDefine Source
fi
