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

function catch() {
    local exit_code=$1
    if [ ${exit_code} != "0" ]; then
        col_echo --red "Error occurred"
        col_echo --red "  Line     : ${BASH_LINENO[1]}"
        col_echo --red "  Function : ${FUNCNAME[1]}"
        col_echo --red "  Command  : ${BASH_COMMAND}"
        col_echo --red "  Exit code: ${exit_code}"
    fi
}

function show_progress() {
    col_echo --blue ">> ${FUNCNAME[1]}"
}
