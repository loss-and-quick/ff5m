#!/bin/bash

## Configuration backup and restore
##
## Copyright (C) 2025, Alexander K <https://github.com/drA1ex>
##
## This file may be distributed under the terms of the GNU GPLv3 license

MOD=/data/.mod/.zmod

CFG_PATH="/opt/config/mod_data/backup.params.cfg"

if [ ! -f $CFG_PATH ]; then
    cp "/opt/config/mod/.shell/cfg/default/backup.params.cfg" "$CFG_PATH"
fi


PARAMS="-p ${CFG_PATH}"

case $1 in
    BACKUP)
        PARAMS="-m backup ${PARAMS}"
    ;;
    RESTORE)
        PARAMS="-m restore ${PARAMS} -w"
    ;;
    VERIFY)
        PARAMS="-m verify ${PARAMS}"
    ;;
    *)
        echo "Unknow parameter: '$1'"
        exit 1
    ;;
esac

if [ "$2" = 1 ]; then PARAMS="$PARAMS --dry"; fi
if [ "$3" = 1 ]; then PARAMS="$PARAMS --verbose"; fi

# TODO: klipper sets LD_PRELOAD variable, idkw
LD_PRELOAD="" chroot $MOD /bin/python3 /root/printer_data/scripts/cfg_backup.py "$PARAMS"
