import os
import re

def setup(oBenchmarkRunner, cores):
  classfiles = []
  ignore = ["LogisticMapAkkaBecomeActorBenchmark.class",  "SucOverRelaxAkkaActorBenchmark.class"]

  pattern = re.compile("^[^$]*Akka[^$]*ActorBenchmark.class")

  for root, dirs, files in os.walk("savina-jvm/target/classes/edu/rice/habanero/benchmarks/"):
    for file in files:
      if (not pattern.fullmatch(file) is None) and (file not in ignore):
        classfiles.append(os.path.join(root, os.path.splitext(file)[0]).replace("savina-jvm/target/classes/", ""))

  nested_args = []

  for classfile in classfiles:
    nested_args.append([["-cp", "savina-jvm/target/savina-0.0.1-SNAPSHOT-jar-with-dependencies.jar"], classfile])

  oBenchmarkRunner.configure("akka", "/usr/bin/java", nested_args)
