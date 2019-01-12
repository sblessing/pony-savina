#!/bin/bash
CREATED=()
LAST=${@: -1}

function levenshtein {
  if [ "${#1}" -lt "${#2}" ]; then
    levenshtein "$2" "$1"
  else
    local str1len=$((${#1}))
    local str2len=$((${#2}))
    local d i j
    
    for i in $(seq 0 $(((str1len+1)*(str2len+1)))); do
      d[i]=0
    done

    for i in $(seq 0 $((str1len)));	do
      d[$((i+0*str1len))]=$i
    done

    for j in $(seq 0 $((str2len)));	do
      d[$((0+j*(str1len+1)))]=$j
    done

    for j in $(seq 1 $((str2len))); do
      for i in $(seq 1 $((str1len))); do
        [ "${1:i-1:1}" = "${2:j-1:1}" ] && local cost=0 || local cost=1
	      local del=$((d[(i-1)+str1len*j]+1))
	      local ins=$((d[i+str1len*(j-1)]+1))
	      local alt=$((d[(i-1)+str1len*(j-1)]+cost))
	      d[i+str1len*j]=$(echo -e "$del\n$ins\n$alt" | sort -n | head -1)
      done
    done
    
    echo ${d[str1len+str1len*(str2len)]}
  fi
}

function cleanup {
  FILES=("$@")

  for i in "${FILES[@]}"; do
    rm ${i}
  done
}

function tech {
  if [[ "$1" =~ "caf" ]]; then
    TECH="CAF"
  elif [[ "$1" =~ "Scala" ]]; then
    TECH="Scala"
  elif [[ "$1" =~ "Akka" ]]; then
    TECH="Akka"
#  elif [[ "$1" =~ "Pony" ]]; then
  else
    TECH="Pony"
  fi
}

function produce_plot {
  PARAM=("$@")
  length=${#PARAM[@]}

  for plot in "${PARAM[@]}"; do
	  NAME=$(echo ${plot} | cut -d ":" -f 1)
    TITLE=$(echo ${plot} | cut -d ":" -f 2)
		TITLE=$(cat plot_config.json | jq -r ".\"benchmarks\"" | jq -r ".\"${TITLE}\"")
    BENCH=$(echo ${plot} | cut -d ":" -f 2 | cut -d "_" -f 2)
    SCRIPT=${NAME}.gnuplot
	  TARGET=""

    tech ${NAME}

		COLOR=$(cat plot_config.json | jq -r ".\"colors\"" | jq -r ".\"${TECH}\"")
		VERSION=$(cat plot_config.json | jq -r ".\"versions\"" | jq -r ".\"${TECH}\"")

	  if (($length > 1)); then
	    TARGET="Combined"
	  else
	    TARGET=${TECH}
	  fi

	  eval "cat plot_${NAME}.txt | sort -t, -k1 -n > gnuplot_${NAME}.txt"
		
#   We might have already plotted this in a non-combined run.
    if [[ ! "${CREATED[@]}" =~ "gnuplot_${NAME}.txt" ]]; then
  	  CREATED+=(gnuplot_${NAME}.txt)
	  fi

    eval "mkdir -p output/${TARGET}/"
    eval "touch output/${TARGET}/${SCRIPT}"

    OUT="output/${TARGET}/${SCRIPT}"
  
    echo "set terminal ${LAST}" >> ${OUT}
    echo "set output \"output/${TARGET}/${TITLE//_/ }.${LAST}\"" >> ${OUT}
    echo "set xlabel 'Cores'" >> ${OUT}
    echo "set ylabel 'Execution Time (Milliseconds, Median)'" >> ${OUT}
    #echo "set logscale y" >> ${OUT}
    echo "set datafile separator \",\"" >> ${OUT}
    echo "set title \"${TITLE}\"" >> ${OUT}

    if (($length > 1)); then
      echo "plot 'gnuplot_${NAME}.txt' using 1:2 with lines title '${TECH} ${VERSION}' lt rgb \"${COLOR}\",\\" >> ${OUT}

		  for next in "${PARAM[@]:1}"; do
		    OTHERNAME=$(echo ${next} | cut -d ":" -f 1)
		    tech ${OTHERNAME}

				COLOR=$(cat plot_config.json | jq -r ".\"colors\"" | jq -r ".\"${TECH}\"")
				VERSION=$(cat plot_config.json | jq -r ".\"versions\"" | jq -r ".\"${TECH}\"")

		    eval "cat plot_${OTHERNAME}.txt | sort -t, -k1 -n > gnuplot_${OTHERNAME}.txt"
		    echo "'gnuplot_${OTHERNAME}.txt' using 1:2 with lines title '${TECH} ${VERSION}' lt rgb \"${COLOR}\",\\" >> ${OUT}

        #We might have already plotted this in a non-combined run.
        if [[ ! "${CREATED[@]}" =~ "gnuplot_${OTHERNAME}.txt" ]]; then
		      CREATED+=(gnuplot_${OTHERNAME}.txt)
		    fi
		  done
	  else
	    echo "plot 'gnuplot_${NAME}.txt' using 1:2 with lines title '${TECH} ${VERSION}' lt rgb \"${COLOR}\"" >> ${OUT}
	  fi

    eval "gnuplot ${OUT}"

	  CREATED+=(${OUT})

	  break
	done
}

ARGS=("$@")
PLOTS=()
combined=false

if [ "$#" -gt 2 ]; then
  combined=true
fi

for folder in ${ARGS[@]::${#ARGS[@]}-1}; do
  FILES=${folder}/**/*.txt

  for benchmark in $FILES; do
    path=$(dirname ${benchmark})
    name=$(grep 'Benchmark:' ${benchmark} | sed 's/^.*: //')
	  id=$(cat plot_config.json | jq -r ".\"$(basename ${benchmark})\"")
	  
    if [[ ! "${PLOTS[@]}" =~ "${name}:${id}" ]]; then
      PLOTS+=("$name:$id")
	    CREATED+=(plot_${name}.txt)
    fi

    core_count=$(basename ${path} | cut -d "_" -f 3)
    best=$(grep 'Best Time:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')
    worst=$(grep 'Worst Time:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')
    median=$(grep 'Median:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')

    echo "${core_count},${median},${best},${worst}" >> plot_${name}.txt
  done
done

for plot in ${PLOTS[@]}; do
  SINGLEPLOT=(${plot})
  produce_plot ${SINGLEPLOT[@]}  
done

if [ "$combined" = true ]; then
  for plot in ${PLOTS[@]}; do
    GROUP=()
    LEAD=$(echo ${plot} | cut -d ":" -f 2)
    hascombined=false

    for next in ${PLOTS[@]}; do
      MATCHING=$(echo ${next} | cut -d ":" -f 2)

	    if [ "$LEAD" = "$MATCHING" ]; then
	      GROUP+=(${next})
		    hascombined=true
	    fi
	  done

    if [ "$hascombined" = true ]; then
      produce_plot ${GROUP[@]}
	  fi

	  for i in ${GROUP[@]}; do
	    PLOTS=(${PLOTS[@]//*$i*})
	  done
  done
fi

cleanup ${CREATED[@]}