from runners.output_parser import PonyOutputParser

def setup(oBenchmarkRunner, cores, memory):
  oBenchmarkRunner.configure("pony", "savina-pony/build/bin/", memory, ["--parseable", "--ponythreads", str(cores)])

def gnuplot(cores, files, results):
  PonyOutputParser(files).parse(cores, results)
