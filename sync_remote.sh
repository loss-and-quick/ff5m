#!/bin/bash


PATH="/bin:/sbin:/usr/bin:/usr/sbin:/opt/bin:/opt/sbin:/opt/bin:/opt/sbin"


SKIP_RESTART=$1
SKIP_MOON_RESTART=$2
SKIP_KLIPPER_RESTART=$3
SKIP_MIGRATE=$4
SKIP_PLUGIN_RELOAD=$5
KLIPPER_HARD_RESTART=$6
REMOTE_DIR=$7
ARCHIVE_NAME=$8
VERBOSE=$9

COMMAND_TIMEOUT=15

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

cleanup() {
    if [ "$VERBOSE" -eq 1 ]; then echo "Cleanup: remove sync files..."; fi
    
    rm ./sync_*.tar*
    rm -r "./.sync"
}

print_status() {
    local name="$1"; local status="$2"; local color="$3"
    echo -e "${NC}► ${name}\t\t${color}${status}${NC}"
}

run_service() {
    if [ "$#" -lt 5 ]; then echo Missing required arguments; exit 3; fi
    
    local name="$1"; local status="$2"; local check_pid="$3"; local skip="$4"
    if [ "$check_pid" -eq 1 ]; then
        if [ "$#" -lt 6 ]; then echo Missing required arguments; exit 3; fi
        local pid_path="$5"; local invert="$6";
        shift 6; local command=("$@")
    else
        shift 4; local command=("$@")
    fi
    
    if [ "$skip" -eq 1 ]; then
        print_status "$name" "${status} skipped." "${BLUE}"
        return 0
    fi
    
    print_status "$name" "${status}..." "${YELLOW}"
    
    if [ "$VERBOSE" -eq 0 ]; then
        ${command[@]} > /dev/null 2>&1
    else
        ${command[@]}
    fi
    
    local ret=$?
    
    if [ "$ret" -ne 0 ]; then
        print_status "$name" "Failed" "${RED}"
        exit 2
    fi
    
    if [ "$check_pid" -eq 0 ]; then
        print_status "$name" "Done" "${GREEN}"
        return
    fi
    
    local pid=$(cat "$pid_path")
    for _ in $(seq 0 $COMMAND_TIMEOUT); do
        kill -0 "$pid" > /dev/null 2>&1; local ret=$?
        if [ $((ret == 0 ? !invert : invert)) -eq 1 ]; then
            print_status "$name" "Done" "${GREEN}"
            return
        fi
        sleep 1
    done
    
    print_status "$name" "Timeout" "${RED}"
    exit 2
}

cd "$REMOTE_DIR" || exit 1

rm -rf "./.sync"
mkdir "./.sync"

echo -e "${BLUE}Extracting archive...${NC}"

gzip -d "./${ARCHIVE_NAME}"
tar -xf "./${ARCHIVE_NAME%.*}" -C "./.sync/"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to extract sync archive${NC}"
    cleanup
    exit 1
fi

echo -e "${BLUE}Comparing files...${NC}"

CHANGED=1

while read -r file; do
    SRC_FILE="$file"
    DEST_FILE="./mod/${file#./.sync/}"
    
    if [ "$VERBOSE" -eq 1 ]; then echo "► Check: $SRC_FILE"; fi
    
    if ! cmp -s "$SRC_FILE" "$DEST_FILE"; then
        echo -e "${YELLOW}► File changed: $DEST_FILE${NC}"
        mkdir -p "${DEST_FILE%/*}" && cp "$SRC_FILE" "$DEST_FILE"
        CHANGED=1
    fi
done < <(find ./.sync -type f)

cleanup

# To avoid restarting after Moonraker's Git repair.
SKIP_REBOOT_F="/data/.mod/.zmod/tmp/zmod_skip_reboot"

if [ "$CHANGED" -eq 1 ] && [ ! -f "$SKIP_REBOOT_F" ]; then
    echo -e "\n${YELLOW}Setup reboot skip for next zmod update${NC}"
    touch "$SKIP_REBOOT_F"
fi

sync

if [ "$SKIP_RESTART" -eq 1 ]; then exit 0; fi

if [ "$CHANGED" -eq 1 ]; then
    echo; echo -e "${GREEN}Restarting services...${NC}\n"
    
    run_service "Moonraker" "Stopping"      1   "$SKIP_MOON_RESTART" \
    "/data/.mod/.zmod/run/moonraker.pid"    1  /etc/init.d/S99root stop
    
    run_service "Database"  "Migrating"     0   "$SKIP_MIGRATE"           /opt/config/mod/.shell/migrate_db.sh
    run_service "Moonraker" "Starting"      0   "$SKIP_MOON_RESTART"      /etc/init.d/S99root start
    
    run_service "Plugins"   "Reloading"     0   "$SKIP_PLUGIN_RELOAD"     /etc/init.d/S00init reload
    
    if [ "$KLIPPER_HARD_RESTART" -ne 1 ]; then
        run_service "Klipper"   "Reloading"     0   "$SKIP_KLIPPER_RESTART"   /opt/config/mod/.shell/restart_klipper.sh
    else
        run_service "Klipper"   "Restarting"    0   "$SKIP_KLIPPER_RESTART"   /opt/config/mod/.shell/restart_klipper.sh --hard
    fi
    
    echo; echo -e "${GREEN}All done!${NC}"
else
    echo; echo -e "${YELLOW}Printer is already in-sync${NC}"
fi
