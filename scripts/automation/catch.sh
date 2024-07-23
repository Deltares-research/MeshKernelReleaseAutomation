#!/bin/bash

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

trap 'catch $?' EXIT
