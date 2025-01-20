#!/bin/sh

## This script will restart Klipper on FlashForge Adventurer 5M(Pro)
## like original QT factory application does it.
##
## This script needs working GDB for operation.
##
## Copyright (c) 2024, Dark Simpson
## Copyright (C) 2025, Alexander K <https://github.com/drA1ex>
##
## This file may be distributed under the terms of the GNU GPLv3 license


unset LD_LIBRARY_PATH
unset LD_PRELOAD
export PATH="$PATH:/opt/bin:/opt/sbin"

# Add also -1 in expression, to avoid capture any other process that interacts with FirwmareExe
pid=$(ps | grep "[f]irmwareExe -1" | awk '{print $1}')

if [ $pid -ne 0 ]; then
    
    echo Screen executable PID is $pid, calling GDB to perform manipulations...
    
    gdb -q <<EOF
# All black magic is done in this GDB script.
# Do not modify anything if you don't understand it!!!

# Do not load all symbold from shared libraries, we do not need them all
set auto-solib-add off

set \$failed = 1

# Attach to our process to perform manipulations
attach $pid

if (_ZN10MainWindow14instMainWindowE != 0)
  # Check that Settings instance already filled
  if (_ZN8Settings12instSettingsE == 0)
    # Open Settings screen
    call _ZN10MainWindow19on_settings_clickedEv(_ZN10MainWindow14instMainWindowE)
  end
else
  echo "MainWindow instance missing\n"
end

if (_ZN8Settings12instSettingsE != 0)
  # Check that we have signal
  if (_ZN8Settings7saveCfgEv != 0)
    # Call saveCfg(), it will also perform Klipper restart (will do it in some seconds)
    call _ZN8Settings7saveCfgEv(_ZN8Settings12instSettingsE)
    set \$failed = 0
  else
    echo "Settings::saveCfg() not found!\n"
  end

  # Open Home screen again
  call _ZN10MainWindow15on_home_clickedEv(_ZN10MainWindow14instMainWindowE)
else
  echo "Global Settings instance not found!\n"
end

# Detach from our process, leave it run freely
detach

# Quit debugger
quit \$failed
EOF
    
    if [ "$?" -ne 0 ]; then
        echo "Error: GDB script finished with an error!"
        exit 2
    fi
    
    echo "Deleting created during restart backup files..."
    find /opt/config -name "printer-$(date +"%Y%m%d")*.cfg" -maxdepth 1 -type f -exec rm -f {} +
else
    echo "Error: Unable to find FirmwareExe process"
    exit 1
fi
