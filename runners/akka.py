import os
import re

def setup(oBenchmarkRunner, cores):
  classfiles = []

  for root, dirs, files in os.walk("savina-jvm/target/classes/edu/rice/habanero/benchmarks/"):
    for file in files:
        if re.match("*Akka*Benchmark*.class", file):
             classfiles.append(os.path.join(root, os.path.splitext(file)[0]))

  nested_args = []

  for classfile in classfiles:
    nested_args.append([["-cp", "savina-jvm/savina-0.0.1-SNAPSHOT-jar-with-dependencies.jar"], classfile])

  oBenchmarkRunner.configure("akka", "/usr/bin/java", nested_args)
