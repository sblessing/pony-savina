#!/bin/bash
shopt -s extglob
DIRECTORIES=$(ls -d ${1}/target/classes/edu/rice/habanero/benchmarks/*/)

for benchmark in $DIRECTORIES; do
  cd $benchmark
        
  FILES=$(ls {*ScalaActor*Benchmark.class,*Akka*Benchmark.class})

  cd - > /dev/null

  for executable in $FILES; do
    if [[ $executable != *\$* ]] ; then
      RUNNER="${executable%.*}"
      java -cp "${1}/target/savina-0.0.1-SNAPSHOT-jar-with-dependencies.jar" ${benchmark#${1}/target/classes/}$RUNNER >> ${3}/${RUNNER}.txt
    fi
  done
done
