#!/bin/bash

set -eu

function GetToolCMake()
{
    local name=$1
    local repo=$2
    local branch=$3
    local src=$4

    local dir=_Tools/$name.work

    rm -fr $dir
    git clone -b $branch $repo $dir/Repo
    cmake -S $dir/Repo/$src -B $dir/Build
    cmake --build $dir/Build --config Release
    cp $dir/Build/$name _Tools/$name
    rm -fr $dir
}

function GetToolRaw()
{
    local name=$1
    local repo=$2
    local src=$3

    local dir=_Tools/$name.work

    rm -fr $dir
    git clone $repo $dir/Repo
    cp $dir/Repo/$src _Tools/$name
    rm -fr $dir
}

if [ ! -f _Tools/int2ssl ]; then
   GetToolCMake int2ssl https://github.com/sfall-team/int2ssl master ""
fi

if [ ! -f _Tools/ReDefine ]; then
   GetToolCMake ReDefine https://github.com/rotators/ReDefine master Source
fi
