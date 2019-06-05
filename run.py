import argparse
import re
import os
import subprocess
import importlib
import stat
import datetime
from pathlib import Path 
from tqdm import tqdm
from os.path import normpath, basename
import json

class HardwareThreading:
  def _cpu_paths(self):
    paths = []

    for path in os.listdir(self._basepath):
      if re.match(r'cpu[0-9]+.*', path):
        paths.append(self._basepath + path)

    return paths

  def _detect_cpus(self):
    for path in self._cpu_paths():
      sibling = -1
      core_id = int(path.split("/")[-1].replace('cpu', ''))
      sibling_path = path + self._siblings
      hyperthread = False
      fullpath = path

      self._cpubind.append(core_id)

      if os.path.isfile(sibling_path):
        with open(sibling_path) as f:
          sibling = int(f.readline().split(",")[0])

          if core_id != sibling:
            if self._hyperthreading:
              self._hyperthreads[core_id] = fullpath
            else:
              self._cpu_file(value = "0", explicit = fullpath)

            hyperthread = True

      if not hyperthread:
        self._cpus[core_id] = fullpath;

  def _detect_numa_placement(self):
    lscpu = subprocess.Popen(["lscpu"], stdout=subprocess.PIPE)
    grep = subprocess.Popen(["grep", "NUMA node[0-9].*"], stdout=subprocess.PIPE, stdin=lscpu.stdout)
    lscpu.stdout.close()

    cut = subprocess.Popen(["cut", "-d", ":", "-f", "2"], stdout=subprocess.PIPE, stdin=grep.stdout)
    grep.stdout.close()

    (output, _) = cut.communicate()

    nodes = output.decode("ascii").split("\n")

    for line in list(filter(None, nodes)):
      line.strip()

      if "-" in line:
        #numa placement is given by range
        interval = line.split("-")
        cores = [i for i in range(int(interval[0]), int(interval[1])) if self._hyperthreading or i in self._cpus.keys()]
      else:
        #numa placement is given absolute
        cores = sorted([int(i) for i in line.split(",") if self._hyperthreading or int(i) in self._cpus.keys()])
      
      self._placement.append(cores)
  
  def _print_system_info(self):
    hyperthread_mode = "on" if self._hyperthreading else "off"
    physical_core_count = len(self._cpus.keys())
    physical_cores = ",".join([str(i) for i in sorted(self._cpus.keys())])
    hyperthread_count = len(self._hyperthreads.keys())
    logical_cores = ",".join([str(i) for i in sorted(self._hyperthreads.keys())])

    print("CPU setup [hyperthreading = %s]:" % (hyperthread_mode))
    print("  %d Physical Cores\t: %s" % (physical_core_count, physical_cores))

    if self._hyperthreading:
      print("  %d Logical Cores\t: %s" % (hyperthread_count, logical_cores))

    for (id, node) in enumerate(self._placement):
      print("  NUMA Node %d\t\t: %s" % (id, ",".join([str(n) for n in node])))

    print("\n")

  def __init__(self, hyperthreads, numactl):
    self._current_node = 0
    self._current_core = 0

    self._hyperthreading = hyperthreads
    self._numactl = numactl
    self._basepath = "/sys/devices/system/cpu/"
    self._siblings = "/topology/thread_siblings_list"
    self._cpus = {}
    self._hyperthreads = {}
    self._placement = []
    self._cpubind = []

  def __enter__(self):
    self._detect_cpus()
    self._detect_numa_placement()
    self._print_system_info() 
    
    return self

  def __exit__(self, type, value, traceback):
    None

  def __iter__(self):
    return self

  def __next__(self):
    while self._current_node < len(self._placement):
      if self._current_core < len(self._placement[self._current_node]):
        n = self._placement[self._current_node][self._current_core]
        self._current_core = self._current_core + 1

        return n
      else:
        self._current_node = self._current_node + 1
        self._current_core = 0

    raise StopIteration
  
  def __len__(self):
    length = 0

    for node in self._placement:
      length += len(node)
    
    return length
  
  def _cpu_file(self, value, core_id = -1, explicit = ""):
    if not self._numactl:
      if not explicit:
        try:
          path = self._cpus[core_id]
        except KeyError:
          path = self._hyperthreads[core_id]
      else:
        if explicit == self._basepath + "cpu0":
          return

        path = explicit
    
      with open(path + "/online", "w") as cpu_file:
        print(value, file=cpu_file)
    else:
      core = core_id if not explicit else int(explicit.replace(self._basepath + "cpu", ""))
      
      if value == "1":
        self._cpubind.append(core)
      else:
        self._cpubind.remove(core)

  def disable(self, core_id = -1, all = False):
    to_disable = None

    if core_id >= 0 and all == False:
      to_disable = [core_id]
    elif all == True:
      to_disable = sorted(self._cpus.keys())[1:] + list(self._hyperthreads.keys())

    for i in to_disable:
      self._cpu_file("0", core_id = i)    

  def enable(self, core_id = -1, all = False):
    if core_id > 0 and all == False:
      self._cpu_file("1", core_id = core_id)
    elif all == True:
      for path in self._cpu_paths():
        self._cpu_file("1", explicit = path)
  
  def get_cpubind(self):
    return self._cpubind

class BenchmarkRunner:
  def __init__(self):
    self._name = None
    self._timestamp = datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')
    self._executables = []
    self._args = []
    self._argument_driven = False
  
  def _get_executables(self, path, exclude):
    executables = []

    executable = stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH

    if not os.path.isfile(path):
      for sFilename in os.listdir(path):
        filepath = path + sFilename if path[-1] == "/" else path + "/" + sFilename
      
        if os.path.isfile(filepath):
          if (os.stat(filepath).st_mode & executable) and sFilename not in exclude:
            executables.append(filepath)
    else:
      # some OS executable with full path supplied
      executables.append(path)
      self._argument_driven = True
    
    return executables

  def _create_directory(self, cores):
    path = "output/" + self._timestamp + "/" + self._name + "/" + str(cores)
    os.makedirs(path, exist_ok=True)

    return path + "/"

  def _run_process(self, output, exe, cpubind, args = []):
    with open(output + ".txt", "w+") as outputfile:
      if not cpubind:
        command = [exe]
      else:
        command = ["numactl", "--physcpubind=" + ",".join(str(i) for i in cpubind), "--", exe]

      bench = subprocess.Popen(command  + args, stdout=outputfile)
      bench.wait()

  def configure(self, name, path, args = [], exclude = []):
    self._name = name
    self._args = args
    self._argument_driven = False
    self._executables = self._get_executables(path, exclude) 
  
  def execute(self, cores, cpubind):
    path = self._create_directory(cores)

    for exe in iter(self._executables):
      if not self._argument_driven:
        output = path + Path(exe).name
        self._run_process(output, exe, cpubind, self._args)
      else:
        for arg in self._args:
          output = path + basename(normpath(arg[-1]))
          self._run_process(output, exe, cpubind, args = arg[0] + [arg[-1]])   

def main():
  numactl = False

  if os.geteuid() != 0:
    print("""
     Running wihtout root privileges. Falling back to `numactl` rather than
     hardware CPU offlining.
    """)

    numactl = True

  parser = argparse.ArgumentParser()
  parser.add_argument('-l', '--hyperthreads', dest='hyperthreads', action='store_true')
  parser.add_argument('-r', "--run", dest='module', action='append')
  parser.add_argument('-n', "--numactl", dest="numactl", action='store_true')
  args = parser.parse_args()

  modules = [importlib.import_module("." + i, package="runners") for i in args.module]

  with HardwareThreading(args.hyperthreads, numactl or args.numactl) as cores:
    cores.disable(all = True)
    core_count = 0
    runner = BenchmarkRunner()

    with tqdm(total=len(cores)*len(modules)) as pbar:
      for core in cores:
        cores.enable(core)
        core_count = core_count + 1

        for module in modules:
          module.setup(runner, core_count)
          runner.execute(core_count, cores.get_cpubind())
          pbar.update(1)
    
    cores.enable(all = True)

if __name__ == "__main__": main()
