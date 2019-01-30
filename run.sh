#!/bin/bash

LAST=${@: -1}
CORES=$(getconf _NPROCESSORS_ONLN)
CORE=1
timestamp=$(date +%s)

while [ $CORE -le $CORES ]
do
	DIR=${1}_${timestamp}_${CORE}
	mkdir -p $DIR
	./cores.sh $CORE
	./${1}.sh ${2} 10 $(pwd)/$DIR ${LAST}
	CORE=$(expr $CORE + 1)
done
