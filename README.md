# pony-savina
Pony: Savina Benchmark Suite (Actor Benchmarks)

## Requirements
  * Pony 0.28.0
  * CAF 0.16.3
  * Python >= 3.5
  * tqdm

            pip install tqdm

## Clone repository with submodules
      git clone --recurse-submodules git@github.com:sblessing/pony-savina.git

## Compile Benchmarks
* Pony  

        cd savina-pony
        mkdir -p build/bin
        cd build/bin
        ponyc ../../

* CAF
        
        cd savina-caf
        mkdir build
        cd build
        cmake ..
        make

* Akka

        cd savina-jvm
        mvn compile
        mvn package

## Run Benchmarks

        python run.py -r [pony|caf|akka] [--hyperthreads]
