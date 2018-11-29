#!/bin/bash
TEMPLATE=$(cat runner_template.txt)
RUNTIME="Pony $(../ponyc/build/release/ponyc --version)"

BEST_RESULT=""
WORST_RESULT=""
MEDIAN_RESULT=""
ARITHMETIC_MEAN_RESULT=""
GEOMETRIC_MEAN_RESULT=""
STANDARD_DEVIATION_RESULT=""
CONFIDENCE_LOW_RESULT=""
CONFIDENCE_HIGH_RESULT=""
VARIATION_RESULT=""
ERROR_WINDOW_RESULT=""
ERROR_WINDOW_PERCENT=""

function float_eval {
    local stat=0
    local result=0.0
    if [[ $# -gt 0 ]]; then
        result=$(echo "scale=3; $*" | bc -l -q 2>/dev/null)
	result=$(printf '%.3f\n' ${result})
        stat=$?
        if [[ $stat -eq 0  &&  -z "$result" ]]; then stat=1; fi
    fi
    echo $result
    return $stat
}

function join {
	local d="$1"; shift; echo -n "$1"; shift; printf "%s" "${@/#/$d}";
}

function best {
	PARAM=("$@")
	BEST_RESULT=${PARAM[0]}
}

function worst {
	PARAM=("$@")
	WORST_RESULT=${PARAM[-1]}
}

function median {
	PARAM=("$@")
	LENGTH=${#PARAM[@]}
	MIDDLE=$((${LENGTH}/2))
	IS_EVEN=$((${LENGTH}%2))

	if [ "${IS_EVEN}" = "0" ]; then
	  MEDIAN_RESULT=${PARAM[$MIDDLE]}
  else
	  EXPR="( ${PARAM[MIDDLE-1]} + ${PARAM[MIDDLE]} ) / 2"
	  MEDIAN_RESULT=$(float_eval "$EXPR")
	fi
}

function arithmetic_mean {
	PARAM=("$@")
	LENGTH=${#PARAM[@]}
  EXPR=$(join "+" ${PARAM[@]})
	SUM="(${EXPR})/${LENGTH}"

	ARITHMETIC_MEAN_RESULT=$(float_eval "$SUM")
}

function geometric_mean {
	PARAM=("$@")
	LENGTH=${#PARAM[@]}

	for i in "${!PARAM[@]}"; do
	  PARAM[$i]=$(float_eval "l(${PARAM[$i]})/l(10)")
	done

	EXPR=$(join "+" ${PARAM[@]})
	BASE=$(float_eval "$EXPR")
	EXPO=$(float_eval "${BASE}/${LENGTH}")

	GEOMETRIC_MEAN_RESULT=$(float_eval "10^${EXPO}")
}

function harmonic_mean {
	PARAM=("$@")
	LENGTH=${#PARAM[@]}

	for i in "${!PARAM[@]}"; do
	  PARAM[$i]=$(float_eval "1/${PARAM[$i]}")
	done

	EXPR=$(join "+" ${PARAM[@]})
	BASE=$(float_eval "$EXPR")

	HARMONIC_MEAN_RESULT=$(float_eval "${LENGTH}/${BASE}")
}

function standard_deviation {
	PARAM=("$@")
	LENGTH=${#PARAM[@]}

	for i in "${!PARAM[@]}"; do
	  PARAM[$i]="(${ARITHMETIC_MEAN_RESULT}-${PARAM[$i]})*(${ARITHMETIC_MEAN_RESULT}-${PARAM[$i]})"
	done

	EXPR=$(join "+" ${PARAM[@]})
	BASE=$(float_eval "${EXPR}/${LENGTH}")

	STANDARD_DEVIATION_RESULT=$(float_eval "sqrt(${BASE})")
}

function confidence_low {
	PARAM=("$@")
	LENGTH=${#PARAM[@]}
	EXPR="${ARITHMETIC_MEAN_RESULT}-(1.96*${STANDARD_DEVIATION_RESULT}/sqrt(${LENGTH}))"

	CONFIDENCE_LOW_RESULT=$(float_eval "$EXPR")
}

function confidence_high {
	PARAM=("$@")
	LENGTH=${#PARAM[@]}
	EXPR="${ARITHMETIC_MEAN_RESULT}+(1.96*${STANDARD_DEVIATION_RESULT}/sqrt(${LENGTH}))"

	CONFIDENCE_HIGH_RESULT=$(float_eval "$EXPR")
}

function error_window {
	ERROR_WINDOW_RESULT=$(float_eval "${CONFIDENCE_HIGH_RESULT}/${ARITHMETIC_MEAN_RESULT}")
	ERROR_WINDOW_PERCENT=$(float_eval "100*((${CONFIDENCE_HIGH_RESULT}-${ARITHMETIC_MEAN_RESULT})/${ARITHMETIC_MEAN_RESULT})")
}

function variation {
	VARIATION_RESULT=$(float_eval "${STANDARD_DEVIATION_RESULT}/${ARITHMETIC_MEAN_RESULT}")
}

#function skewness {
#
#}

for bench in $(./$1 -l); do
  RESULTS=()
  STDOUT=()

	for i in `seq 1 $2`; do
	  START=`date +%s.%N`
	  STDOUT+=(./$1 -b=$bench)
          END=`date +%s.%N`

          DIFF=`echo "$END - $START" | bc | awk -F"." '{print $1""substr($2,1,3)}' |  awk '{printf "%.3f", $0}'`
	  RESULTS+=(${DIFF})
	  STDOUT+=("${bench}\tIteration-$i:  ${DIFF} ms")
	done

	SORTED_RESULTS=( 
		$( 
			for (( i=0; i<${#RESULTS[@]}; i++ ))
      do
        echo ${RESULTS[i]}
      done | sort 
		) 
	)

	best ${SORTED_RESULTS[@]}
	worst ${SORTED_RESULTS[@]}
	median ${SORTED_RESULTS[@]}
	arithmetic_mean ${SORTED_RESULTS[@]}
	geometric_mean ${SORTED_RESULTS[@]}
  harmonic_mean ${SORTED_RESULTS[@]}
	standard_deviation ${SORTED_RESULTS[@]}
	confidence_low ${SORTED_RESULTS[@]}
	confidence_high ${SORTED_RESULTS[@]}
	error_window ${SORTED_RESULTS[@]}
	variation ${SORTED_RESULTS[@]}
	#SKEWNESS_RESULT=skewness ${SORTED_RESULTS[@]}

	OUTFILE=${TEMPLATE}
	OUTFILE=${OUTFILE/__RUNTIME__/${RUNTIME}}
	OUTFILE=${OUTFILE//__BENCHMARK__/${bench}}
	OUTFILE=${OUTFILE//__NUMBER_OF_ITERATIONS__/$2}

	iterations=$(join "\n" ${STDOUT[@]})

	echo ${iterations}

	OUTFILE=${OUTFILE//__BEST__/${BEST_RESULT}}
	OUTFILE=${OUTFILE//__WORST__/${WORST_RESULT}}
	OUTFILE=${OUTFILE//__MEDIAN__/${MEDIAN_RESULT}}
	OUTFILE=${OUTFILE//__ARITHMETIC_MEAN__/${ARITHMETIC_MEAN_RESULT}}
	OUTFILE=${OUTFILE//__GEOMETRIC_MEAN__/${GEOMETRIC_MEAN_RESULT}}
	OUTFILE=${OUTFILE//__HARMONIC_MEAN__/${HARMONIC_MEAN_RESULT}}
	OUTFILE=${OUTFILE//__STANDARD_DEVIATION__/${STANDARD_DEVIATION_RESULT}}
	OUTFILE=${OUTFILE//__CONFIDENCE_LOW__/${CONFIDENCE_LOW_RESULT}}
	OUTFILE=${OUTFILE//__CONFIDENCE_HIGH__/${CONFIDENCE_HIGH_RESULT}}
	OUTFILE=${OUTFILE//__ERROR_WINDOW__/${ERROR_WINDOW_RESULT}}
	OUTFILE=${OUTFILE//__PERCENT__/${ERROR_WINDOW_PERCENT}}
	OUTFILE=${OUTFILE//__VARIANCE__/${VARIATION_RESULT}}
	
	echo "${OUTFILE}" #>> /home/sebastian/Development/PhD/${3}/${bench}.txt


done
