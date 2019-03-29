#!/bin/bash
#first, disable all cores, then enable up to $1 many cores
#respecting numa placement and hyper threading.

#!/bin/bash

LOGICAL_CORES=()
NUMA_PLACEMENT=()
LAST=${@: -1}

function detect_hyperthreading {
  typeset -i core_id
  typeset -i sibling_id
  typeset -i state

  for i in /sys/devices/system/cpu/cpu[0-9]*; do
    core_id="${i##*cpu}"
    sibling_id="-1"
  
    if [ -f ${i}/topology/thread_siblings_list ]; then
      sibling_id="$(cut -d',' -f1 ${i}/topology/thread_siblings_list)"
    fi
  
    if [ $core_id -ne $sibling_id ]; then
      LOGICAL_CORES+=($core_id)
    fi    
  done  
}

function detect_numa_placement {
  #numa placement can be given in ranges
  #or explicitly
  typeset -i index
  typeset -i core_id

  placement=$(lscpu | grep "NUMA node[0-9].*" | cut -d ":" -f 2)
  index=0

  for node in ${placement[@]}; do
    if [[ $node == *"-"* ]]; then   #list of numa placement is a range
      IFS='-' read -r -a core_range <<< "$node"
        START="${core_range[0]}"
        END="${core_range[1]}"
        CORE_IDS=$(seq $START $END)
    elif [[ $node == *","* ]]; then #list of numa placement is explicit
      IFS=',' read -r -a CORE_IDS <<< "$node"
    fi

    IDS=""

    for core_id in "${CORE_IDS[@]}"; do
      if [ -z "$IDS" ]; then
        IDS=$core_id
      else
        IDS=$IDS","$core_id
      fi
    done

    NUMA_PLACEMENT[$index]=$IDS

    index=$(expr $index + 1)
  done
}

function join {
  local d=$1; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}";
}

if [ ! -f hyperthreading.log ]; then
  echo "" > hyperthreading.log

  detect_hyperthreading

  for logical_core in ${LOGICAL_CORES[@]}; do
    echo "$logical_core" >> hyperthreading.log
  done
else
  IFS=$'\r\n' GLOBIGNORE='*' command eval  'LOGICAL_CORES=($(cat hyperthreading.log))'
fi


if [ ! -f numa.log ]; then
  echo "" > numa.log

  detect_numa_placement
  
  for node in ${NUMA_PLACEMENT[@]}; do
    echo "${node}" >> numa.log
  done
else
  IFS=$'\r\n' GLOBIGNORE='*' command eval  'NUMA_PLACEMENT=($(cat numa.log))'
fi

CPU=( $(ls -d -1 /sys/devices/system/cpu/* | grep -E "cpu[0-9]+" | sort -V) )
ITER=0

#core 0 is always enabled and cannot be disabled
CORES=$(expr $1 - 1)
HYPERTHREADING=false
PHYSICAL=false

if [ "$LAST" = "hyperthreading" ]; then
  HYPERTHREADING=true
elif [ "$LAST" = "physical" ]; then
  PHYSICAL=true
else
  HYPERTHREADING=true
  PHYSICAL=false
fi

#Check arguments
if [[ $1 -gt ${#CPU[@]} ]]; then
  echo "Trying to enable more cores then available! Consider activating hyper threading!";  exit 1
fi

#First, disable all cores irrespective of
#numa placement and hyperthreading,
#except core 0 (which can never be
#disabled).
for core in ${CPU[@]}; do
  if [[ $ITER -gt 0 ]]; then
    echo 0 > "$core/online"
    echo "Disable: $core"
  fi

  ITER=$(expr $ITER + 1)
done

ITER=0

# If hyperthreading should not be used, remove
# all logical cores from the node list
if [ "$HYPERTHREADING" = false ]; then
  for logical_core in ${LOGICAL_CORES[@]}; do
    unset CPU[$logical_core]

    for node in "${!NUMA_PLACEMENT[@]}"; do
       IFS=',' read -r -a PLACEMENT <<< "${NUMA_PLACEMENT[$node]}"
       for i in "${!PLACEMENT[@]}"; do
         if [[ ${PLACEMENT[i]} = "$logical_core" ]]; then
           unset 'PLACEMENT[i]'
         fi
       done
      
       NUMA_PLACEMENT[$node]=$(join , ${PLACEMENT[@]})
       PLACEMENT=()
    done
  done
fi

OFFSET=0

NODE_LIST=${NUMA_PLACEMENT[$ITER]}

IFS=',' read -r -a CURRENT <<< "$NODE_LIST"

for index in $(seq 1 $CORES); do
  while true; do
    target=$(expr $index - $OFFSET)

    if [[ ${CURRENT[$target]} ]]; then
      core=${CPU[${CURRENT[$target]}]}
      echo "Enable: $core"
      echo 1 > "$core/online"
      break
    else
      ITER=$(expr $ITER + 1)
      OFFSET=${#CURRENT[@]}
      
      NODE_LIST=${NUMA_PLACEMENT[$ITER]}
      CURRENT=()

      if [[ ${NUMA_PLACEMENT[$ITER]} ]]; then
        IFS=',' read -r -a CURRENT <<< "$NODE_LIST"
      else
        echo "NUMA nodes exhausted!"; exit 1
      fi
    fi
  done
done
