#!/bin/bash
CREATED=()
HTML=()
LAST=${@: -1}

hasmemory=false

read -r -d '' THUMBNAIL << EOM
  <a href="https://www.doc.ic.ac.uk/~scb12/benchmarks/__PLOT__.pdf" class="thumbnail">
    <img src="https://www.doc.ic.ac.uk/~scb12/benchmarks/__THUMB__.png" class="img-thumbnail">
  </a>
EOM

read -r -d '' ROW << EOM 
  <div class="col-md-4">
    __THUMBNAIL__0
    __THUMBNAIL__1
    __THUMBNAIL__2
  </div>
EOM

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
    ISCOMBINED=false

    tech ${NAME}

    COLOR=$(cat plot_config.json | jq -r ".\"colors\"" | jq -r ".\"${TECH}\"")
    VERSION=$(cat plot_config.json | jq -r ".\"versions\"" | jq -r ".\"${TECH}\"")

    if (($length > 1)); then
      TARGET="Combined"
      ISCOMBINED=true
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
    OUTPUT=${TITLE// /_}
    OUTPUT=${OUTPUT//\(/}
    OUTPUT=${OUTPUT//\)/}

    if [ "$ISCOMBINED" = true ]; then
      if [[ ! "${HTML[@]}" =~ "${OUTPUT}" ]]; then
        HTML+=(${OUTPUT})
      fi
    fi
  
    echo "set terminal ${LAST}" >> ${OUT}
    echo "set output \"output/${TARGET}/${OUTPUT}.${LAST}\"" >> ${OUT}

    if [ "$hasmemory" = true ]; then
		  echo "set hidden3d" >> ${OUT}
		  echo "set dgrid3d 50,50 qnorm 2" >> ${OUT}
    fi

    echo "set xlabel 'Cores'" >> ${OUT}

    if [ "$hasmemory" = true ]; then
      echo "set ylabel 'Profiled Time (Milliseconds, Median)' rotate parallel" >> ${OUT}
      echo "set zlabel 'Peak memory (Megabytes, Average)' rotate parallel" >> ${OUT}
    else
      echo "set ylabel 'Execution Time (Milliseconds, Median)'" >> ${OUT}
    fi

    #echo "set logscale y" >> ${OUT}
    echo "set xtics 4" >> ${OUT}
    echo "set datafile separator \",\"" >> ${OUT}
    echo "set title \"${TITLE}\"" >> ${OUT}

		if [ "$hasmemory" = false ]; then
      echo "set key outside" >> ${OUT}
		fi

    if (($length > 1)); then
      if [ "$hasmemory" = true ]; then
        echo "splot 'gnuplot_${NAME}.txt' using 1:2:5 with lines title '${TECH} ${VERSION}' lt rgb \"${COLOR}\" lw 1,\\" >> ${OUT}
      else
        echo "plot 'gnuplot_${NAME}.txt' using 1:2 with lines title '${TECH} ${VERSION}' lt rgb \"${COLOR}\" lw 2,\\" >> ${OUT}
      fi

      for next in "${PARAM[@]:1}"; do
        OTHERNAME=$(echo ${next} | cut -d ":" -f 1)
        tech ${OTHERNAME}

        COLOR=$(cat plot_config.json | jq -r ".\"colors\"" | jq -r ".\"${TECH}\"")
        VERSION=$(cat plot_config.json | jq -r ".\"versions\"" | jq -r ".\"${TECH}\"")

        eval "cat plot_${OTHERNAME}.txt | sort -t, -k1 -n > gnuplot_${OTHERNAME}.txt"

        if [ "$hasmemory" = true ]; then
          echo "'gnuplot_${OTHERNAME}.txt' using 1:2:5 with lines title '${TECH} ${VERSION}' lt rgb \"${COLOR}\" lw 1,\\" >> ${OUT}
        else
          echo "'gnuplot_${OTHERNAME}.txt' using 1:2 with lines title '${TECH} ${VERSION}' lt rgb \"${COLOR}\" lw 2,\\" >> ${OUT}
        fi

        #We might have already plotted this in a non-combined run.
        if [[ ! "${CREATED[@]}" =~ "gnuplot_${OTHERNAME}.txt" ]]; then
          CREATED+=(gnuplot_${OTHERNAME}.txt)
        fi
      done
    else
      if [ "$hasmemory" = true ]; then
        echo "splot 'gnuplot_${NAME}.txt' using 1:2:5 with lines title '${TECH} ${VERSION}' lt rgb \"${COLOR}\" lw 1" >> ${OUT}
      else
        echo "plot 'gnuplot_${NAME}.txt' using 1:2 with lines title '${TECH} ${VERSION}' lt rgb \"${COLOR}\" lw 2" >> ${OUT}
      fi
    fi

    eval "gnuplot ${OUT}"

    if [[ ! "${CREATED[@]}" =~ "${OUT}" ]]; then
      CREATED+=(${OUT})
    fi

    break
  done
}

function produce_html {
  TEMPLATE=$(cat pony.txt)
  COUNT=0
  CURRENT=${ROW}
  HTML_OUT=()

  for generated in ${HTML[@]}; do
    if [ $COUNT -eq 3 ]; then
      HTML_OUT+=(${CURRENT})
      CURRENT=${ROW}
      COUNT=0
    fi

    THUMB=${THUMBNAIL/"__PLOT__"/$generated}
    THUMB=${THUMB/"__THUMB__"/$generated}
    CURRENT=${CURRENT/"__THUMBNAIL__${COUNT}"/$THUMB}
    COUNT=$((COUNT+1))
  done

  ##DOM=$(join "\n" ${HTML_OUT[@]})
  TEMPLATE=${TEMPLATE/__PLOTS__/${HTML_OUT[@]}}
  echo ${TEMPLATE} >> "pony.html"
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
    file=$(basename ${benchmark})
    id=$(cat plot_config.json | jq -r ".\"${file}\"")
    key=${file//".txt"/}

    if [[ ! "${PLOTS[@]}" =~ "${key}:${id}" ]]; then
      PLOTS+=("$key:$id")
      CREATED+=(plot_${key}.txt)
    fi

    core_count=$(basename ${path} | cut -d "_" -f 3)
    best=$(grep 'Best Time:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')
    worst=$(grep 'Worst Time:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')
    median=$(grep 'Median:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')
    memory=$(grep 'Avg. peak memory:' ${benchmark} | sed 's/^.*: //' | egrep -o '[0-9]+.[0-9]+')

    if [ -n "$memory" ]; then
      hasmemory=true
      echo "${core_count},${median},${best},${worst},${memory}" >> "plot_${key}.txt"
    else
      echo "${core_count},${median},${best},${worst}" >> "plot_${key}.txt"
    fi
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

produce_html
cleanup ${CREATED[@]}
