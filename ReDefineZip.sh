#!/bin/bash

set -eu

LANG=C
LC_ALL=C

readonly home=$(pwd)

set +e
option_7z=$(command -v 7z)
option_int2ssl=$(command -v int2ssl)
option_redefine=$(command -v ReDefine)
set -e

option_mod=

for option in "$@"; do
    [[ "$option" == "--debug" ]] && set -x
    [[ "$option" =~ ^--7z=(.+)$ ]] && option_7z=${BASH_REMATCH[1]}
    [[ "$option" =~ ^--int2ssl=(.+)$ ]] && option_int2ssl=${BASH_REMATCH[1]}
    [[ "$option" =~ ^--redefine=(.+)$ ]] && option_redefine=${BASH_REMATCH[1]}
    [[ "$option" =~ ^--mod=(.+)$ ]] && option_mod=${BASH_REMATCH[1]}
done

function Usage()
{
    echo ""
    echo "USAGE:  $0 [options]"
    echo ""
    echo "OPTIONS"
    echo ""
    echo "  --debug"
    echo "  --mod=some/path       path to repacked mod"
    echo "  --7z=some/path        path to 7z     (ignore if executable is in PATH)"
    echo "  --int2ssl=some/path   path to int2ssl  (ignore if executable is in PATH)"
    echo "  --redefine=some/path  path to ReDefine (ignore if executable is in PATH)"
    echo ""
    echo "ZIP"
    echo ""
    echo "  Repacked mod content:"
    echo "  - (required) *.INT"
    echo "  - (optional) AI.TXT       used to generate ai.h"
    echo "  - (optional) MAPS.TXT     used to generate maps.h"
    echo "  - (optional) SCRIPTS.LST  used to generate scripts.h"
    echo "  - (optional) VAULT13.GAM  used to generate global.h"
    echo ""
    echo "  - (optional) Headers/     used as-is instead of generating from data files"
    echo ""
    exit 1
}

if   [ -z "$option_mod" ]; then
     echo "Missing argument: --mod"
     Usage
elif [ ! -f "$option_mod" ]; then
     echo "Missing mod file: $option_mod"
     Usage
elif [[ ! "$option_mod" =~ ^[A-Za-z0-9\.\/]+\.zip$ ]]; then
     echo "Invalid mod name : $name"
     Usage
elif [ -z "$option_int2ssl" ] || [ ! -x "$option_int2ssl" ]; then
     echo "int2ssl not found or invalid : $option_int2ssl"
     Usage
elif [ -z "$option_redefine" ] || [ ! -x "$option_redefine" ]; then
     echo "ReDefine not found or invalid : $option_redefine"
     Usage
fi

readonly mod_zip=$option_mod                           #  Path/To/Mod.File.zip
readonly mod_namepath=${mod_zip%.*}                    #  Path/To/Mod.File
readonly mod_namepath_escaped=${mod_namepath//\//\\/}  #  Path\/To\/Mod
readonly mod_basezip=$(basename $mod_zip)              #  Mod.File.zip
readonly mod_name=${mod_basezip%.*}                    #  Mod.File

readonly p7z="$option_7z"
readonly int2ssl="$option_int2ssl"
readonly redefine="$option_redefine"

readonly src_headers=_Headers
readonly dir_headers=$mod_namepath/Headers
readonly dir_headers_shared=$dir_headers/Shared

readonly dir_before=$mod_namepath/Original
readonly dir_errors=$mod_namepath/Errors
readonly dir_after=$mod_namepath/ReDefine

if [[ -d $mod_namepath/ ]]; then
    echo "Preparing directory : $mod_zip -> $mod_namepath/"
    rm -fR $mod_namepath/
fi

echo "Processing package : $mod_zip -> $mod_namepath/"

"$p7z" x "$mod_zip" "-o$mod_namepath" >/dev/null

header=
readonly generated="Generated automagically from"
ai_txt=$(find $mod_namepath/ -type f -iname 'ai.txt')
maps_txt=$(find $mod_namepath/ -type f -iname 'maps.txt')
scripts_lst=$(find $mod_namepath/ -type f -iname 'scripts.lst')
vault13_gam=$(find $mod_namepath/ -type f -iname 'vault13.gam')

redefine_cfg=$(find $mod_namepath/ -type f -iname 'redefine.cfg')
redefine_merge_cfg=$(find $mod_namepath/ -type f -iname 'redefine.cfg')

#for header in command_lite.h define_trait.h; do
#    if [ ! -f $src_headers/$header ]; then
#       continue
#    fi
#
#   column -t -e $src_headers/$header > $src_headers/$header.tmp
#   mv $src_headers/$header.tmp $src_headers/$header
#
#   sed -ri 's/^#(ifndef|define)  /#\1 /' $src_headers/$header
#done

# if mod is packed with its own headers directory,
# use it as-is without generating any header
if [ -d $dir_headers ]; then
   ignore_datafiles=1
else
   ignore_datafiles=0
   mkdir -p $dir_headers
   cp -r $src_headers $dir_headers_shared
fi

function IniToHeader()
{
    local header=$1
    local key=$2
    local prefix=
    if (( $# >= 3 )); then
       prefix=$3
    fi

    # poor man's dos2unix
    sed -ri 's/\r//g' $header

   # remove all lines except sections and specific key
   sed -ri "/(^[\\t\\ ]*\\[.+\\]|^[\\t\\ ]*${key})/!d" $header

   # remove everything after section name
   sed -ri 's/\].*/]/' $header

   # replace keys with its values only
   sed -ri "s/^[\\t\\ ]*${key}[\\t\\ ]*=[\\t\\ ]*(.+)/\\1/" $header
   sed -ri "s/[\\t\\ ]*;.*//" $header

   # uppercase all lines
   sed -ri 's/^(.*)$/\U\1/' $header

   # remove invalid characters
   sed -ri 's/[\,]+//g' $header

   # replace invalid characters with _
   sed -ri 's/[-\ ]+/_/g' $header

   # merge lines pairs into single line with value and name
   sed -ri 'N;s/^\[(.+)\]\n(.+)/\2 \1/Mg' $header

   # sort by value
   sort -h -o $header $header

   # create defines
   if [ -n "$prefix" ]; then
      sed -ri "s/^(.+) (.+)$/#define ${prefix}_\2 \1/" $header
   else
      sed -ri "s/^(.+) (.+)$/#define \2 \1/" $header
   fi
}

# prettify and add include guards, for no good reason
function PrettyHeader()
{
    local header=$1
    local from=$2
    local guard=$3

    from=$(echo "$from" | sed -e "s!^$mod_namepath/!$mod_basezip/!")
    column -t $header > $header.tmp
    mv $header.tmp $header
    sed -ri 's/define  /define /' $header
    sed -ri "1s!^!#ifndef $guard\n#define $guard\n\n// $generated $from //\n\n!" $header
    echo "" >> $header
    echo "#endif // $guard //" >> $header

    sed -ri 's/[\t\ ]+$//' $header
}

#
# AI.TXT
#

if [ $ignore_datafiles -eq 0 ] && [ -n "$ai_txt" ] && [ -f "$ai_txt" ]; then
   echo "- Process AI.TXT"
   header=$dir_headers/ai.h
   mv "$ai_txt" $header

   IniToHeader $header packet_num AI

   # tweak defines - add parens
   sed -ri 's/define (.+) ([0-9]+)/define \1 (\2)/' $header

   # tweak defines - better names
   sed -ri 's/define AI_PLAYER_AI/define AI_PLAYER/' $header

   PrettyHeader $header "$ai_txt" __AI__

else
   ai_txt=
fi

#
# MAPS.TXT
#

if [ $ignore_datafiles -eq 0 ] && [ -n "$maps_txt" ] && [ -f "$maps_txt" ]; then
   echo "- Process MAPS.TXT"
   header=$dir_headers/maps.h
   mv "$maps_txt" $header

   IniToHeader $header map_name

   # tweak defines - switch name and value, add parens
   sed -ri 's/MAP_([0-9]+) (.+)$/MAP_\2 (\1)/' $header

   # tweak defines - remove leading 0s
   sed -ri 's/\([0]+([1-9]+)\)/(\1)/g' $header
   sed -ri 's/\([0]+\)/(0)/g' $header

   cur="$(cat $header)"
   echo "//" >> $header
   cur="$(echo "$cur" | sed -re 's/MAP_([A-Za-z0-9_]+).*/CUR_MAP_\1 \(cur_map_index == MAP_\1\)/')"
   echo "$cur" >> $header

   PrettyHeader $header "$maps_txt" __MAPS__
   sed -ri 's/  ==  / == /g' $header
else
   maps_txt=
fi

#
# SCRIPTS.LST
#

if [ $ignore_datafiles -eq 0 ] && [ -n "$scripts_lst" ]; then
   echo "- Process SCRIPTS.LST"
   header=$dir_headers/scripts.h

   id=0
   while IFS="" read -r line || [ -n "$line" ]
   do
         id=$((id + 1))
         echo "$id $line" >> $header
   done < $scripts_lst
   rm -f $scripts_lst

   # remove local_vars info
   sed -ri 's/[\t\ ]*#[\t\ ]*local_vars[\t\ ]*=.*//g' $header

   # remove comments
   sed -ri 's/[\t\ ]*\;.*//g' $header

   # create defines
   # happily consume kinda invalid entries as well (NAME.ssl instead of NAME.int)
   sed -ri 's/^([0-9]+)[\t ]+([A-Za-z0-9_]+)\.([Ii][Nn][Tt]|[Ss][Ss][Ll])[\t\ ]*.*/#define SCRIPT_\U\2 (\1)/' $header

   PrettyHeader $header "$scripts_lst" __SCRIPTS__
else
   scripts_lst=
fi

#
# VAULT13.GAM
#

if [ $ignore_datafiles -eq 0 ] && [ -n "$vault13_gam" ] && [ -f "$vault13_gam" ]; then
   echo "- Process VAULT13.GAM"
   header=$dir_headers/global.h
   mv $vault13_gam $header

   # remove all lines except gvar definitions
   sed -ri '/^[\t\ ]*[A-Za-z0-9_]+[\t\ ]*:=[\t\ ]*[-]?[0-9]+/!d' $header

   # remove everything except gvar name
   sed -uri 's/[\t\ ]*\:.+//g' $header

   # create defines
   id=-1
   while IFS="" read -r line || [ -n "$line" ]
   do
         id=$((id+1))
         echo "#define $line ($id)" >> $header.tmp
   done < $header
   mv $header.tmp $header

   PrettyHeader $header "$vault13_gam" __GLOBAL__
else
   vaut13_gam=
fi

#
# Decompile setup
#

mkdir -p $dir_before $dir_after

if [ -f $dir_headers/scripts.h ]; then
   have_scripts_h=1
else
   have_scripts_h=0
fi

int2ssl_1=

if [ -f "$mod_namepath/1" ]; then
   rm -f "$mod_namepath/1" ];
   int2ssl_1=-1
   echo "- Decompile as Fallout 1 script"
fi

mkdir -p "$mod_namepath.tmp"

#
# Normalize filenames: uppercase name, lowercase extension
#

find "$mod_namepath/" -type f -iname '*.int' | while read int; do
     int_base="$(basename "$int")"
     int_name="${int_base%.*}"
     int_uclc="$(dirname "$int")/${int_name^^}.int"

     if [[ "$int" != "$int_uclc" ]]; then
        mv "$int" "$int_uclc"
     fi
done

#
# Decompile
#

find "$mod_namepath/" -type f -iname '*.int' | sort | while read int; do
     ssl="${int%.*}.ssl"
     err="${int%.*}.txt"
     dmp="${int%.*}.dmp"

     ssl_base="$(basename "$ssl")"
     md=

     echo "- Decompile $int"

     set +e
     "$int2ssl" $int2ssl_1 -s4 -- "$int" "$ssl" > "$err"
     set -e

     if [ -s "$ssl" ]; then
        ssl_ok=1
        dos2unix --quiet "$ssl"
        cp "$ssl" $dir_after
       #chmod -f 0444 "$ssl"
        mv "$ssl" $dir_before
        ssl_base_md="${ssl_base//\ /\*}"
        ssl_base_20="${ssl_base//\ /%20}"
        md="| [Original/$ssl_base_md]($(basename "$dir_before")/$ssl_base_20) | [ReDefine/$ssl_base_md]($(basename "$dir_after")/$ssl_base_20) | diff | - |"
     else
        ssl_ok=0

        echo "- Decompile $int -> $dir_errors/$(basename "$err")"
        sed -ri 's!\r!\n!g' "$err"

        set +e
        $int2ssl $int2ssl_1 -s4 -d -- "$int" "$dmp" >/dev/null
        set -e

        if [ -s "$dmp" ]; then
           echo "" >> "$err"
           cat "$dmp" >> "$err"
        fi

        # keep error report and uncompiled script in dedicated directory,
        # in case anyone wants to debug/improve int2ssl :)
        mkdir -p "$dir_errors"
       #chmod -f 0444 "$err"
        mv "$err" "$dir_errors"
        mv "$int" "$dir_errors"

        # create dummy file to avoid confusion
        see_err="$(basename "$dir_errors")/$(basename "$err")"
        see_err_20="${see_err//\ //%20}"
        see_err_md="${see_err//\ /\*}"

        echo "See: [$see_err](../$see_err_20)" > "$dir_before/${ssl_base%.*}.md"
        echo "See: [$see_err](../$see_err_20)" > "$dir_after/${ssl_base%.*}.md"

        md="| - | - | - | [$see_err_md]($see_err_20) |"
     fi
     echo "$md" >> "$mod_namepath/.INDEX"
     rm -f "$int" "$ssl" "$err" "$dmp"

#
# QuickEdit
# Try to find SID for decompiled script, and replace raw number with "NAME" string,
# which allows to use some fancy replacements - *Option(), mstr(), etc.
#

     if [[ $have_scripts_h -ne 1 ]] || [[ $ssl_ok -ne 1 ]]; then
        continue
     fi

     ssl_define=$(echo "SCRIPT_${ssl_base%.*}" | tr '[a-z]' '[A-Z]')
     ssl_id=$(egrep --max-count=1 "^#define[\\t\\ ]+$ssl_define[\\t\\ ]+" $dir_headers/scripts.h | sed -e 's!\r!!g' | awk '{print $3}' | tr -d '()') #'
     ssl_cfg="$dir_after/${ssl_base%.*}.cfg"

     if [ -z "$ssl_id" ]; then
        continue
     elif [[ ! "$ssl_id" =~ ^[0-9]+$ ]]; then
        echo "[ERROR] INVALID SID '$ssl_id'"
        exit 1
     fi

     echo "
[ReDefine]
HeadersDir=$src_headers
ScriptsDir=$mod_namepath.tmp

LogFile    = $dir_after/$ssl_base.log
LogDebug   = $dir_after/$ssl_base.DEBUG.log
LogWarning = $dir_after/$ssl_base.WARNING.log

$(egrep '^FormatFunctions ' ReDefine.cfg)
$(egrep '^UnixNewlines ' ReDefine.cfg)

[Defines]
DUMMY = dummy.h DUMMY

[Defines:SID]
 0 = 0
-1 =-1
$ssl_id = NAME

[Function]" > "$ssl_cfg"
     # copy functions config, keeping only those with SID as argument
     # this _should_ omit any script edits, as they're not allowed to use spaces
     # this _would_ break if there's SID in [Variable]
     cfg="$(egrep '=.*[ ]+SID([ ]+|$)' ReDefine.cfg)"
     cfg=$(echo "$cfg" | sed -re 's/ SID( |$)/ ---1207---\1/g') #'
     cfg=$(echo "$cfg" | sed -re 's/[A-Z]+/?/g')
     cfg=$(echo "$cfg" | sed -re 's/---1207---/SID/g')
     echo "$cfg" >> "$ssl_cfg"
    #echo "+ Created $ssl_cfg"

     mv "$dir_after/$ssl_base" $mod_namepath.tmp
     "$redefine" --config "$ssl_cfg" >/dev/null
     # https://stackoverflow.com/a/1616754/11998612
     changed="$(grep '^Changed' "$dir_after/$ssl_base.log" | awk '{$1=$2=$3=$6=$7=$8="";$0=$0;$1=$1}1')"
     if [ -n "$changed" ]; then
        echo "- QuickEdit $dir_after/$ssl_base -> NAME = $ssl_define = $ssl_id -> $changed"
     fi
     mv "$mod_namepath.tmp/$ssl_base" $dir_after
     rm -f "$mod_namepath.tmp/*"
done
rm -fr "$mod_namepath.tmp"

#
# ReDefine
#

#if [ -n "$redefine_cfg" ]; then
#   echo "- Process $dir_after/ -> using custom configuration"
#   mv "$redefine_cfg" "$mod_namepath.cfg"
#else if [ -n "$redefine_merge_cfg" ]; then
#   echo "- Process $dir_after/ -> using merged configuration"
#   mv "$redefine_cfg" "$mod_namepath.cfg"
#
#else
   cp ReDefine.cfg "$mod_namepath.cfg"
#fi

echo "- Prepare $mod_namepath.cfg"
sed -ri "s/@NAME@/$mod_name/g"                 "$mod_namepath.cfg"
sed -ri "s/@NAMEPATH@/$mod_namepath_escaped/g" "$mod_namepath.cfg"

echo "- Process $dir_after/"
$redefine --config "$mod_namepath.cfg" >/dev/null
rm -fR $mod_namepath.cfg $dir_headers_shared
total=$(grep '^Process scripts ... ' "$mod_namepath.log" | awk '{$1=$2=$3="";$0=$0;$1=$1}1')
changed="$(grep '^Changed' "$mod_namepath.log" | awk '{$1=$2=$3="";$0=$0;$1=$1}1')"
if [ -n "$changed" ]; then
   echo "- Process $dir_after/ -> $total (total)"
   echo "- Process $dir_after/ -> $changed (changed)"
fi

echo "- Create .diff files"
find $dir_before/ -type f -iname '*.ssl' | sort | while read ssl; do
     ssl_base="$(basename "$ssl")"
     ssl_base_re="${ssl_base//\./\\.}"
     ssl_base_re="${ssl_base_re//\ /\\*}"
     ssl_base_re="${ssl_base_re//\(/\\(}"
     ssl_base_re="${ssl_base_re//\)/\\)}"
     set +e
     git diff --no-index -- "$dir_before/$ssl_base" "$dir_after/$ssl_base" > "$mod_namepath/$ssl_base.diff"
     set -e

     if [[ -s "$mod_namepath/$ssl_base.diff" ]]; then
        ssl_base_re_20="${ssl_base_re//\*/%20}"
        sed -ri "s/^\| (\[Original\/$ssl_base_re\].+) \| diff \| (.+) \|$/| \1 | [$ssl_base_re.diff]($ssl_base_re_20.diff) | \2 |/" "$mod_namepath/.INDEX"
     else
        echo "- Skip $mod_namepath/$ssl_base.diff"
        sed -ri "s/^\| (\[Original\/$ssl_base_re\].+) \| diff \| (.+) \|$/| \1 | - | \2 |/" "$mod_namepath/.INDEX"
        rm -f "$mod_namepath/$ssl_base.diff"
     fi
done

if [[ -f "$mod_namepath/.INDEX" ]]; then
   sed -i '1 i | Original | ReDefine | Diff | Error |' "$mod_namepath/.INDEX"
   column -t "$mod_namepath/.INDEX" > "$mod_namepath/.INDEX.md"
   separator="$(head -n 1 "$mod_namepath/.INDEX.md" | sed -e 's/[^\|]/-/g')"
   sed -i "2i $separator" "$mod_namepath/.INDEX.md"
   sed -i 's!\*!\ !g' "$mod_namepath/.INDEX.md"
  #sed -i '1s/^/\n/' "$mod_namepath/.INDEX.md"
   rm -f "$mod_namepath/.INDEX"
fi

#
# Cleanup
#

echo "- Cleanup"

find $mod_namepath/ -type d -empty | sort | while read dir; do
     echo "- Deleting $dir/"
     rm -fR $dir
done

find $dir_before/ -type f -iname '*.int' | sort | while read int; do
     echo "- Deleting $int"
     rm -f "$int"
done

#echo "$(basename $dir_errors)/" >> $mod_namepath/.gitignore
#echo "$(basename $dir_before)/" >> $mod_namepath/.gitignore
#echo "$(basename $dir_after)/"  >> $mod_namepath/.gitignore
