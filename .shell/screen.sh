#!/bin/bash

## Screen drawing script
##
## Copyright (C) 2025, Alexander K <https://github.com/drA1ex>
##
## This file may be distributed under the terms of the GNU GPLv3 license

source /opt/config/mod/.shell/common.sh

load_version() {
    export FIRMWARE_VERSION=$(cat /root/version)
    export MOD_VERSION=$(cat /opt/config/mod/version.txt)
}

print_message() {
    local text="$1"
    
    "$BINS/typer" fill -p 0 380 -s 800 80
    "$BINS/typer" text -ha center -p 400 400 -c 00f0f0 -b 0 -f "Roboto 12pt" -t "$text"
}

print_progress() {
    local value="$1"
    
    value=$((value > 100 ? 100 : value))
    
    "$BINS/typer" fill -p 200 420 -s 400 40 -c 872187
    "$BINS/typer" fill -p 205 425 -s 390 30 -c 0
    
    local progress_width=$(( value * 380 / 100 ))
    "$BINS/typer" fill -p 210 430 -s $progress_width 20 -c 872187
}

case "$1" in
    draw_loading)
        load_version
        xzcat /opt/config/mod/load.img.xz > /dev/fb0
        "$BINS/typer" text -ha center -p 235 380 -c 00f0f0 -f "JetBrainsMono Bold 12pt" -t "v$MOD_VERSION"
        "$BINS/typer" text -ha center -p 584 380 -c 00f0f0 -f "JetBrainsMono Bold 12pt" -t "v$FIRMWARE_VERSION"
    ;;
    
    draw_splash)
        load_version
        xzcat /opt/config/mod/splash.img.xz > /dev/fb0
        "$BINS/typer" text -ha center -p 235 335 -c 035050 -f "JetBrainsMono Bold 12pt" -t "v$MOD_VERSION"
        "$BINS/typer" text -ha center -p 584 335 -c 035050 -f "JetBrainsMono Bold 12pt" -t "v$FIRMWARE_VERSION"
    ;;
    
    boot_message)
        if [ -z "$2" ]; then
            echo "message text is missing"
            exit 1
        fi
        
        uptime=$(awk '{print $1}' < /proc/uptime)
        
        "$BINS/typer" fill -p 0 440 -s 800 40
        "$BINS/typer" text -ha center -p 400 460 -c ffffff -b 0 -f "JetBrainsMono Bold 8pt" -t "$uptime >>  $2"
    ;;
    
    print_file)
        if [ -z "$2" ]; then
            echo "File name is missing"
            exit 1
        fi
        
        print_message "$2"
        print_progress 0
    ;;
    
    print_progress)
        if [ -z "$2" ]; then
            echo "Progress value is missing"
            exit 1
        fi
        
        print_progress "$2"
    ;;
    
    end_print)
        message="$2"
        if [ -z "$message" ]; then
            message="Finished!"
        fi
        
        print_message "$message"
        print_progress "100"
    ;;
    
    *)
        echo "Usage: $0 <command> [args...]"
        exit 1
esac