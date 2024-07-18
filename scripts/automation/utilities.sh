#!/bin/bash

function col_echo() {
    local color=$1
    local text=$2
    if ! [[ ${color} =~ '^[0-9]$' ]]; then
        case $(echo ${color} | tr '[:upper:]' '[:lower:]') in
        --black | -k)
            color=0
            ;;
        --red | -r)
            color=1
            ;;
        --green | -g)
            color=2
            ;;
        --yellow | -y)
            color=3
            ;;
        --blue | -b)
            color=4
            ;;
        --magenta | -m)
            color=5
            ;;
        --cyan | -c)
            color=6
            ;;
        --white | -w)
            color=7
            ;;
        *) # default color
            color=9
            ;;
        esac
    fi
    tput setaf ${color}
    echo ${text}
    tput sgr0
}

function show_progress() {
    col_echo --blue ">> ${FUNCNAME[1]}"
}

function print_text_box() {
    local string="$1"
    local length=${#string}
    local border="+-$(printf "%${length}s" | tr ' ' '-')-+"

    col_echo --green "$border"
    col_echo --green "| $string |"
    col_echo --green "$border"
}
