for bench in $(./pony-savina -l); do
	for i in `seq 1 10`; do
		for j in `seq 1 $1`; do
			result=$( { /usr/bin/time -f '%e' ./pony-savina --ponythreads $j -b=$bench > /dev/null; } 2>&1 )
			echo "$i,$bench,$result"
		done
	done	
done
