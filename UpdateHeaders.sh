#!/bin/bash

set -eu

dir_orig=_Headers/SFall
dir_edit=_Headers/ReDefine
dir_sfall=$dir_orig.work

function GetHeader()
{
    local name=$1

    if [[ ! -f $dir_sfall/artifacts/scripting/headers/$name ]]; then
       echo "[ERROR] SFall header<$name> not found"
       exit 1
    fi

    mkdir -p $dir_orig $dir_edit

    cp $dir_sfall/artifacts/scripting/headers/$name $dir_orig
    cp $dir_sfall/artifacts/scripting/headers/$name $dir_edit
}

function SedHeader()
{
    local name="$1"
    local edit="$2"

    sed -ri "$edit" $dir_edit/$name
}

function PutHeader()
{
    local name=$1
    local orig=$dir_orig/$name
    local edit=$dir_edit/$name

    set +e
    git diff --no-index -- $orig $edit > _Headers/$name.diff
    set -e

    if [[ ! -s _Headers/$name.diff ]]; then
       rm -f _Headers/$name.diff
    fi

    mv $edit _Headers/$name

    rm -f $orig
}

rm -fr $dir_sfall $dir_orig $dir_edit
git clone --quiet -b develop https://github.com/sfall-team/sfall.git $dir_sfall

GetHeader define_lite.h
# wrong prefix
SedHeader define_lite.h 's/(^[\t\ ]*#.+)DEFINE_METARULE_/\1METARULE_/g'
# moved to separate header
SedHeader define_lite.h '/Trait defines/d'
SedHeader define_lite.h '/define TRAIT_PERK/d'
SedHeader define_lite.h '/define TRAIT_OBJECT/d'
SedHeader define_lite.h '/define TRAIT_TRAIT/d'
# ewww
SedHeader define_lite.h 's/define SKILL_CONVERSANT/define SKILL_SPEECH    /g'
SedHeader define_lite.h 's/SKILL_CONVERSANT/SKILL_SPEECH/g'
# duplicate of STAT_max_hp
SedHeader define_lite.h '/STAT_max_hit_points/d'
# duplicate
SedHeader define_lite.h '/METARULE_TEST_FIRSTRUN/ {:a;n;n;/METARULE_TEST_FIRSTRUN/{d;bb};ba;:b}'
PutHeader define_lite.h

GetHeader define_extra.h
PutHeader define_extra.h

GetHeader command_lite.h
PutHeader command_lite.h

GetHeader sfall.h
PutHeader sfall.h

rm -fr $dir_sfall $dir_orig $dir_edit
