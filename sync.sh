#!/bin/bash

## Synchronize local changes to the printer
##
## Copyright (C) 2025, Alexander K <https://github.com/drA1ex>
##
## This file may be distributed under the terms of the GNU GPLv3 license

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color


REMOTE_HOST=""
REMOTE_USER="root"
REMOTE_DIR="/opt/config/"
ARCHIVE_NAME="sync_$(date +%Y%m%d_%H%M%S).tar.gz"

SKIP_HEAVY=0

SKIP_RESTART=0
SKIP_MOON_RESTART=0
SKIP_KLIPPER_RESTART=0
SKIP_MIGRATE=0

KLIPPER_HARD_RESTART=0

HELP=0
VERBOSE=0

while [ "$#" -gt 0 ]; do
    param=$1; shift
    case $param in
        --host|-h)
            REMOTE_HOST="$1"; shift
            echo -e "${BLUE}[+] Remote host: ${REMOTE_HOST}.${NC}"
        ;;
        --skip-restart|-sr)
            SKIP_RESTART=1
            echo -e "${BLUE}[+] Services restart will be skipped.${NC}"
        ;;
        --skip-moon-restart)
            SKIP_MOON_RESTART=1
            echo -e "${BLUE}[+] Moonraker restart will be skipped.${NC}"
        ;;
        --skip-klipper-restart)
            SKIP_KLIPPER_RESTART=1
            echo -e "${BLUE}[+] Klipper restart will be skipped.${NC}"
        ;;
        --skip-database)
            SKIP_MIGRATE=1
            echo -e "${BLUE}[+] Database migration will be skipped.${NC}"
        ;;
        --skip-heavy|-sh)
            SKIP_HEAVY=1
            echo -e "${BLUE}[+] Heavy files will be skipped.${NC}"
        ;;
        --hard-klipper-restart)
            KLIPPER_HARD_RESTAR=1
            echo -e "${BLUE}[+] Klipper hard restart mode enabled.${NC}"
        ;;
        --verbose|-v)
            echo -e "${BLUE}[+] Vebose mode enabled.${NC}"
            VERBOSE=1
        ;;
        --help|-h)
            HELP=1
        ;;
        *)
            HELP=1
            echo -e "${RED}Unknow parameter: \"${param}\"${NC}"
        ;;
    esac
done

if [ "$HELP" = 1 ] || [ -z "$REMOTE_HOST" ]; then
    echo -e "${RED}Usage:${NC} $0 --host <printer_ip> [options]"
    echo -e ""
    echo -e "${BLUE}Options:${NC}"
    echo -e "    --host, -h               Specify the remote printer's IP address."
    echo -e "    --skip-heavy, -sh        Skip transferring heavy files."
    echo -e "    --skip-restart, -sr      Skip restarting the services."
    echo -e "    --skip-database          Skip database migration."
    echo -e "    --skip-moon-restart      Skip restarting Moonraker."
    echo -e "    --skip-klipper-restart   Skip restarting Klipper."
    echo -e "    --hard-klipper-restart   Use Hard restart for Klipper."
    echo -e "    --verbose, -v            Enable verbose mode for detailed output."
    echo -e "    --help, -h               Display this help message."
    echo -e ""
    echo -e "${RED}Example:${NC} $0 --host 192.168.1.100 --skip-restart --verbose"
    exit 1
fi

cleanup() {
    rm "./${ARCHIVE_NAME}"
}

abort() {
    trap SIGINT
    echo; echo 'Aborted'
    cleanup
    
    exit 2
}

trap "abort" INT

declare -a EXCLUDES=(
    "./${ARCHIVE_NAME}"
    ".git"
    ".idea"
    ".vscode"
    ".DS_Store"
    "./sync*.tar.gz"
    "./sync.sh"
)

if [ "$SKIP_HEAVY" -eq 1 ]; then
    EXCLUDES+=(
        "./.shell/root/docs/"
        "./.shell/root/config/"
        "./.shell/root/klippy/"
        "./.shell/root/moonraker/"
        "./.zsh/.oh-my-zsh/"
    )
fi

echo -e "${BLUE}Creating archive...${NC}"

EXCLUDE_STR=""
for e in "${EXCLUDES[@]}"; do
    EXCLUDE_STR+="--exclude='$e' "
    if [ "$VERBOSE" -eq 1 ]; then echo "► Excluding: \"$e\""; fi
done

eval "tar $EXCLUDE_STR --disable-copyfile -czf \"${ARCHIVE_NAME}\" ."
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Unable to create sync archive.${NC}"
    
    cleanup
    exit 2
fi

echo -e "${BLUE}Uploading archive to ${REMOTE_HOST}...${NC}"
scp -O "./${ARCHIVE_NAME}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"

if [ $? -ne 0 ]; then
    echo -e "\n${RED}Unable to upload sync archive to the printer at ${REMOTE_HOST}.${NC}"
    echo "Make sure you have added identity to the printer:"
    echo "ssh-copy-id -i \"/path/to/ssh_key.pub\" root@${REMOTE_HOST}"
    
    cleanup
    exit 2
fi

ssh "${REMOTE_USER}@${REMOTE_HOST}" bash -l << EOF
    ##############################################

    cleanup() {
        if [ "$VERBOSE" -eq 1 ]; then echo "Cleanup: remove sync files..."; fi

        rm ./sync_*.tar*
        rm -r "./.sync"
    }

    print_status() {
        local name="\$1"; local status="\$2"; local color="\$3"
        echo -e "${NC}► \${name}\t\t\${color}\${status}${NC}"
    }

    run_service() {
        if [ "\$#" -lt 5 ]; then echo Missing required arguments; exit 3; fi

        local name="\$1"; local status="\$2"; local check_pid="\$3"
        if [ "\$check_pid" -eq 1 ]; then
            if [ "\$#" -lt 6 ]; then echo Missing required arguments; exit 3; fi
            local pid_path="\$4"; local invert="\$5"; local skip="\$6"
            shift 6; local command=("\$@")
        else
            local skip="\$4"
            shift 4; local command=("\$@")
        fi

        if [ "\$skip" -eq 1 ]; then
            print_status "\$name" "\${status} skipped." "${BLUE}"
            return 0
        fi

        print_status "\$name" "\${status}..." "${YELLOW}"

        if [ "$VERBOSE" -eq 0 ]; then
            \${command[@]} > /dev/null 2>&1
        else
            \${command[@]}
        fi

        local ret=\$?

        if [ "\$ret" -ne 0 ]; then
            print_status "\$name" "Failed" "${RED}"
            exit 2
        fi

        if [ "\$check_pid" -eq 0 ]; then
            print_status "\$name" "Done" "${GREEN}"
            return
        fi

        local pid=\$(cat "\$pid_path")
        for i in \$(seq 0 15); do
            kill -0 "\$pid" > /dev/null 2>&1; local ret=\$?
            if [ \$((ret == 0 ? !invert : invert)) -eq 1 ]; then
                print_status "\$name" "Done" "${GREEN}"
                return
            fi
            sleep 1
        done

        print_status "\$name" "Timeout" "${RED}"
        exit 2
    }

    ##############################################

    cd "${REMOTE_DIR}" || exit 1

    rm -rf "./.sync"
    mkdir "./.sync"

    echo -e "${BLUE}Extracting archive...${NC}"

    gzip -d "./${ARCHIVE_NAME}"
    tar -xf "./${ARCHIVE_NAME%.*}" -C "./.sync/"

    if [ \$? -ne 0 ]; then
        echo -e "${RED}Failed to extract sync archive${NC}"
        cleanup
        exit 1
    fi

    echo -e "${BLUE}Comparing files...${NC}"

    CHANGED=0

    while read -r file; do
        SRC_FILE="\$file"
        DEST_FILE="./mod/\${file#./.sync/}"

        if [ "$VERBOSE" -eq 1 ]; then echo "► Check: \$SRC_FILE"; fi

        if ! cmp -s "\$SRC_FILE" "\$DEST_FILE"; then
            echo -e "${YELLOW}► File changed: \$DEST_FILE${NC}"
            mkdir -p "\${DEST_FILE%/*}" && cp "\$SRC_FILE" "\$DEST_FILE"
            CHANGED=1
        fi
    done < <(find ./.sync -type f)

    cleanup

    # To avoid restarting after Moonraker's Git repair.
    SKIP_REBOOT_F="/data/.mod/.zmod/tmp/zmod_skip_reboot"

    if [ "\$CHANGED" -eq 1 ] && [ ! -f "\$SKIP_REBOOT_F" ]; then
        echo -e "\n${YELLOW}Setup reboot skip for next zmod update${NC}"
        touch "\$SKIP_REBOOT_F"
    fi

    if [ "$SKIP_RESTART" -eq 1 ]; then exit 0; fi

    if [ "\$CHANGED" -eq 1 ]; then
        echo; echo -e "${GREEN}Restarting services...${NC}\n"

        run_service "Moonraker" "Stopping"      1   "$SKIP_MOON_RESTART" \
            "/data/.mod/.zmod/run/moonraker.pid"    1  /etc/init.d/S99moon stop

        run_service "Database"  "Migrating"     0   "$SKIP_MIGRATE"           /opt/config/mod/.shell/migrate_db.sh
        run_service "Moonraker" "Starting"      0   "$SKIP_MOON_RESTART"      /etc/init.d/S99moon up

        if [ "$KLIPPER_HARD_RESTART" -ne 1 ]; then
        run_service "Klipper"   "Restarting"    0   "$SKIP_KLIPPER_RESTART"   /opt/config/mod/.shell/restart_klipper.sh --hard
        else
        run_service "Klipper"   "Reloading"     0   "$SKIP_KLIPPER_RESTART"   /opt/config/mod/.shell/restart_klipper.sh
        fi

        echo; echo -e "${GREEN}All done!${NC}"
    else
        echo; echo -e "${YELLOW}Printer is already in-sync${NC}"
    fi
EOF

ret=$?

cleanup

if [ "$ret" -ne 0 ]; then
    echo -e "\n${RED}Unable to sync files to the printer at ${REMOTE_HOST}.${NC}"
    exit 2
fi

echo; echo -e "${GREEN}Sync complete!${NC}"
