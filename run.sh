for bench in $(./pony-savina -l); do
	for i in `seq 1 10`; do
		result=$( { time ./pony-savina -b=$bench > /dev/null; } 2>&1 )
		echo "$i,$bench,$result"
	done	
done
