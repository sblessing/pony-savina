def setup(oBenchmarkRunner, cores):
  oBenchmarkRunner.configure("pony", "savina-pony/build/bin/", ["--parseable --ponythreads " + str(cores)])
