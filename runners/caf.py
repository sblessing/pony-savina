from runners.output_parser import SavinaOutputParser

def setup(oBenchmarkRunner, cores, memory):
  exclude = [
    "caf_14_logmap_become_unbecome_fast",
    "caf_14_logmap_become_unbecome_slow",
    "caf_14_logmap_request_await_high_timeout",
    "caf_15_banking_become_unbecome_fast",
    "caf_15_banking_become_unbecome_slow",
    "caf_15_banking_request_await_high_timeout",
    "caf_15_banking_request_await_infinite",
    "caf_15_banking_request_then_high_timeout"
  ]

  oBenchmarkRunner.configure("caf", "savina-caf/build/bin", memory, args = ["--scheduler.max-threads=" + str(cores)], exclude = exclude)

def gnuplot(cores, files, results):
  SavinaOutputParser(files).parse(cores, results) 