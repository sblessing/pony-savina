def setup(oBenchmarkRunner, cores):
  oBenchmarkRunner.configure("pony", "savina-pony/build/bin/savina-pony", ["--ponythreads " + str(cores)])
