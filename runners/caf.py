from runners import runner

def run(cores):
  oRunner = runner.BenchmarkRunner(runner.ExecutableRunner).instance()
  oRunner.initialize("caf", "savina-caf/build/bin")
  oRunner.execute(cores)
