#!/bin/bash
#first, disable all cores, then enable up to $1 many cores
#not respecting numa placement.

CPU=$(ls -d -1 /sys/devices/system/cpu/* | grep -E "cpu[0-9]+" | sort -V)

ITER=0

#core 0 is always enabled and cannot be disabled
CORES=$(expr $1 - 1)

for core in $CPU 
do
  if [[ $ITER -gt 0 && $CORES -gt 0 ]]; then 
     echo 1 > "$core/online"
     CORES=$(expr $CORES - 1)
  else 
     if [[ $ITER -gt 0 ]]; then
       echo 0 > "$core/online"
     fi
  fi

  ITER=$(expr $ITER + 1)
done
