#!/bin/bash
FILES=${1}/*

for benchmark in $FILES
do
   logfile=${3}/$(basename $benchmark).txt
   ./$benchmark >> $logfile
done
