def setup(oBenchmarkRunner, cores):
  oBenchmarkRunner.configure("pony", "savina-pony/build/bin/savina-pony", ["--ponynoyield", "--ponythreads " + str(cores)])
