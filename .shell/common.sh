#!/bin/bash

## Mod's common variables and functions
##
## Copyright (C) 2025, Alexander K <https://github.com/drA1ex>
##
## This file may be distributed under the terms of the GNU GPLv3 license


MOD=/data/.mod/.zmod
SCRIPTS=/opt/config/mod/.shell
CMDS=$SCRIPTS/commands
MOD_DATA=/opt/config/mod_data

NOT_FIRST_LAUNCH_F="/tmp/not_first_launch_f"
CUSTOM_BOOT_F="/tmp/custom_boot_f"

CFG_SCRIPT="$CMDS/zconf.sh"
VAR_PATH="$MOD_DATA/variables.cfg"

unset LD_PRELOAD

logged() {
    local print=true
    local print_formatted=false
    local log=true
    local log_file=""
    local log_level="     "
    local log_format="%date% | %level% | %pid% | %script%:%line% | %message%"
    
    while [[ $# -gt 0 ]]; do
        local param="$1"; shift
        case "$param" in
            --no-print)
                print=false
            ;;
            --print-formatted)
                print_formatted=true
            ;;
            --no-log)
                log=false
            ;;
            --log-level)
                log_level="$1"; shift
            ;;
            --log-format)
                log_format="$1"; shift
            ;;
            *)
                if [[ -z "$log_file" ]]; then
                    log_file="$param"
                else
                    echo "Unknown option: $param" >&2
                    return 1
                fi
            ;;
        esac
    done
    
    if $log && [ -z "$log_file" ]; then
        echo "Error: Log file not specified." >&2
        return 1
    fi

    if ! $log && ! $print; then
        echo "Error: Printing and logging disabled." >&2
        return 1
    fi
    
    while IFS= read -r line; do
        local date_str="$(date '+%Y-%m-%d %H:%M:%S')"
        local pid=$$
        local script_name=$(basename "$0")
        local line_number=${BASH_LINENO[0]:-unknown}
        local func_name=${FUNCNAME[1]:-global}
        local line_log_level=$log_level

        if [[ $line = "@@"* ]]; then
            line_log_level="ERROR"; line="${line:2}"
        elif [[ $line = "??"* ]]; then
            line_log_level="WARN "; line="${line:2}"
        elif [[ $line = "//"* ]]; then
            line_log_level="INFO "; line="${line:2}"
        fi

        line="${line#"${line%%[![:space:]]*}"}"
        
        local log_entry="$log_format"
        log_entry="${log_entry//'%date%'/$date_str}"
        log_entry="${log_entry//'%level%'/$line_log_level}"
        log_entry="${log_entry//'%pid%'/$pid}"
        log_entry="${log_entry//'%func%'/$func_name}"
        log_entry="${log_entry//'%line%'/$line_number}"
        log_entry="${log_entry//'%script%'/$script_name}"
        log_entry="${log_entry//'%message%'/$line}"
        
        if $print; then
            if $print_formatted; then
                printf "%s\n" "$log_entry"
            else
                printf "%s\n" "$line"
            fi
        fi
        
        if $log; then
            printf "%s\n" "$log_entry" >> "$log_file"
        fi
    done
}
