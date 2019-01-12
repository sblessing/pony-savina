#!/bin/bash

FILES=${1}/**/*.txt
PLOTS=()

for benchmark in $FILES
do
  path=$(dirname ${benchmark})
  name=$(grep 'Benchmark:' ${benchmark} | sed 's/^.*: //')
  
  if [[ ! "${PLOTS[@]}" =~ "${name}" ]]; then
    PLOTS+=("$name")
  fi

  core_count=$(basename ${path} | cut -d "_" -f 3)
  best=$(grep 'Best Time:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')
  worst=$(grep 'Worst Time:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')
  median=$(grep 'Median:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')

  echo "${core_count},${median},${best},${worst}" >> plot_${name}.txt
done

for plot in ${PLOTS[@]}
do
  eval "cat plot_${plot}.txt | sort -t, -k1 -n >> gnuplot_${plot}.txt"
  rm plot_${plot}.txt

  BENCH=$(echo ${plot} | cut -d "_" -f 3)
  SCRIPT=${plot}.gnuplot

  eval "touch ${SCRIPT}"
  
  echo "set terminal pdf" >> ${SCRIPT}
  echo "set output \"${plot}.pdf\"" >> ${SCRIPT}
  echo "set xlabel 'Cores'" >> ${SCRIPT}
  echo "set ylabel 'Execution Time (Median)'" >> ${SCRIPT}
  echo "set datafile separator \",\"" >> ${SCRIPT}
  echo "set title \"${BENCH}\"" >> ${SCRIPT}
  echo "plot 'gnuplot_${plot}.txt' using 1:2 with lines title 'CAF'" >> ${SCRIPT}
  eval "gnuplot ${SCRIPT}"
   
 
  rm ${SCRIPT}
  rm gnuplot_${plot}.txt   
done
