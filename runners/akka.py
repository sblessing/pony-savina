import os
import re
from runners.output_parser import SavinaOutputParser

def setup(oBenchmarkRunner, cores, memory):
  classfiles = []

  exclude = [
    "BankingAkkaAwaitActorBenchmark.class",
    "BankingAkkaBecomeActorBenchmark.class",
    "BankingAkkaManualStashActorBenchmark.class",
    "GuidedSearchAkkaPriorityActorBenchmark.class",
    "LogisticMapAkkaBecomeActorBenchmark.class", 
    "LogisticMapAkkaAwaitActorBenchmark.class",
    "LogisticMapAkkaManualStashActorBenchmark.class" ,
    "NQueensAkkaPriorityActorBenchmark.class",
    "SucOverRelaxAkkaActorBenchmark.class"
  ]

  pattern = re.compile("^[^$]*Akka[^$]*ActorBenchmark.class")

  for root, dirs, files in os.walk("savina-jvm/target/classes/edu/rice/habanero/benchmarks/"):
    for file in files:
      if (not pattern.fullmatch(file) is None) and (file not in exclude):
        classfiles.append(os.path.join(root, os.path.splitext(file)[0]).replace("savina-jvm/target/classes/", ""))

  nested_args = []

  for classfile in classfiles:
    nested_args.append([["-Dhj.numWorkers=" + str(cores), "-cp", "savina-jvm/target/savina-0.0.1-SNAPSHOT-jar-with-dependencies.jar"], classfile])

  oBenchmarkRunner.configure("akka", "/usr/bin/java", memory, nested_args)

def gnuplot(cores, files, results):
  SavinaOutputParser(files).parse(cores, results)
