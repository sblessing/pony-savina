for bench in $(./pony-savina -l); do
	for i in `seq 1 10`; do
		for j in `seq 1 $1`; do
		  start=$(date +%s.%N)
			./pony-savina --ponythreads $j -b=$bench > /dev/null
			end=$(date +%s.%N)
			diff=$(echo "$end - $start" | bc | awk '{printf "%f", $0}')
			echo "$i,$j,$bench,$diff"
		done
	done	
done
