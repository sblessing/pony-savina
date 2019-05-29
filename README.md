# pony-savina
Pony: Savina Benchmark Suite (Actor Benchmarks)

## Requirements
  * Pony 0.28.0
  * CAF
  * Python >= 3.5

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

## Run Benchmarks

        python run.py -r [pony|caf] [--hyperthreads]
