#!/usr/bin/env bash
#{{{                    MARK:Header
#**************************************************************
##### Author: MenkeTechnologies
##### GitHub: https://github.com/MenkeTechnologies
##### Date: Thu Sep  5 22:34:56 EDT 2019
##### Purpose: bash script to
##### Notes:
#}}}***********************************************************
if [[ -n "$ZPWR" && -n "$ZPWR_LIB_INIT" ]]; then
    if ! source "$ZPWR_LIB_INIT" ""; then
        echo "Could not source dir '$ZPWR_LIB_INIT'."
        exit 1
    fi
else
    source="${BASH_SOURCE[0]}"
    while [ -h "$source" ]; do # resolve $source until the file is no longer a symlink
    zpwrBaseDir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$zpwrBaseDir/$source" # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    zpwrBaseDir="$( cd -P "$( dirname "$source" )" >/dev/null 2>&1 && pwd )"

    while [[ ! -f "$zpwrBaseDir/.zpwr_root" ]]; do
        zpwrBaseDir="$(dirname "$zpwrBaseDir")"
        if [[ "$zpwrBaseDir" == / ]]; then
            echo "Could not find .zpwr_root file up the directory tree." >&2
            exit 1
        fi
    done
    if ! source "$zpwrBaseDir/scripts/init.sh" "$zpwrBaseDir"; then
        echo "Could not source zpwrBaseDir '$zpwrBaseDir/scripts/init.sh'."
        exit 1
    fi

    unset zpwrBaseDir
fi

zpwrCommandExists rpm && rpm_cmd='{ rpm -qi $file; rpm -qlp $file; }' || rpm_cmd="stat"
zpwrCommandExists dpkg && deb_cmd='{ dpkg -I $file; dpkg -c $file; }' || deb_cmd="stat"

os="$(uname -s)"
if echo "$os" | grep -iq darwin; then
    nmcmd="nm"
elif echo "$os" | grep -iq linux; then
    nmcmd="nm -D"
else
    nmcmd="nm"
fi

casestr=$(cat<<EOF
            base=\${file##*/}
            case \$base in
                (*.txt)
                    $FZF_COLORIZER_FILE_TEXT 2>/dev/null;
                    ;;
                ([!.]*.*)
                    $FZF_COLORIZER_FILE 2>/dev/null;
                    ;;
                (.*.*)
                    $FZF_COLORIZER_FILE 2>/dev/null;
                    ;;
                (*)
                    $FZF_COLORIZER_FILE_DEFAULT 2>/dev/null;
                    ;;
            esac

EOF
    )

BAT_OFFSET=3
START_OFFSET=20
cat<<EOF

test -z \$file && file=\$(cut -d: -f1 <<< {} | sed "s@^~@$HOME@");
lineNum=\$(cut -d: -f2 <<< {});
lineNum=\$((lineNum + $BAT_OFFSET))
startNum=\$((lineNum - $START_OFFSET))
if (( startNum < 1)); then
    startNum=1
fi
if test -f \$file;then
    if print -r -- \$file | command grep -E -iq "\\.[jw]ar\$";then jar tf \$file | $FZF_COLORIZER_JAVA;
    elif print -r -- \$file | command grep -E -iq "\\.(tgz|tar|tar\\.gz)\$";then tar tf \$file | $FZF_COLORIZER_C;
    elif print -r -- \$file | command grep -E -iq "\\.deb\$";then $deb_cmd | $FZF_COLORIZER_SH;
    elif print -r -- \$file | command grep -E -iq "\\.rpm\$";then $rpm_cmd | $FZF_COLORIZER_SH;
    elif print -r -- \$file | command grep -E -iq "\\.zip\$";then unzip -v -- \$file | $FZF_COLORIZER_C;
    elif print -r -- \$file | command grep -E -iq "\\.(bzip|bz)\$";then bzip -c -d \$file | $FZF_COLORIZER_YAML;
    elif print -r -- \$file | command grep -E -iq "\\.(bzip2|bz2)\$";then bzip2 -c -d \$file | $FZF_COLORIZER_YAML;
    elif print -r -- \$file | command grep -E -iq "\\.(xzip|xz)\$";then xz -c -d \$file | $FZF_COLORIZER_YAML;
    elif print -r -- \$file | command grep -E -iq "\\.(gzip|gz)\$";then gzip -c -d \$file | $FZF_COLORIZER_YAML;
    elif print -r -- \$file | command grep -E -iq "\\.(so|dylib).*\$";then
        $ZPWR_FZF_CLEARLIST
        $nmcmd \$file | $FZF_COLORIZER_YAML
        xxd \$file | $FZF_COLORIZER_YAML
    else
EOF


cat<<EOF
        if LC_MESSAGES=C command grep -Hm1 "^" "\$file" | command grep -q "^Binary";then
            $ZPWR_FZF_CLEARLIST
            test -x \$file && objdump -d \$file | $FZF_COLORIZER_YAML
            xxd \$file | $FZF_COLORIZER_YAML
        else
            $casestr
        fi
    fi
fi | perl -ne "if (\$lineNum .. \$lineNum){s@\\\x1b\\\[[0-9;]+m@@g;s@(.*)@\\\x1b[$ZPWR_MARKER_COLOR\\\$1\\\x1b[0m@;print} elsif (\$startNum .. eof) {print;}"
EOF
