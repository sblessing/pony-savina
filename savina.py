import argparse
import re
import os
import subprocess

class HardwareThreading:
  def _detect_cpus(self):
    for sPath in os.listdir(self._basepath):
      if re.match(r'cpu[0-9]+.*', sPath):
        iSibling = -1
        iCoreId = int(sPath.split("/")[-1].replace('cpu', ''))
        sSiblingPath = self._basepath + sPath + self._siblings
        bHyperthread = False
        sFullpath = self._basepath + sPath

        if os.path.isfile(sSiblingPath):
          with open(sSiblingPath) as f:
            iSibling = int(f.readline().split(",")[0])

            if iCoreId != iSibling:
              if not self._bPhysical:
                self._hyperthreads[iCoreId] = sFullpath
              
              bHyperthread = True

        if not bHyperthread:
          self._cpus[iCoreId] = sFullpath;

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
        cores = [i for i in range(int(interval[0]), int(interval[1])) if not self._bPhysical or i in self._cpus.keys()]
      else:
        #numa placement is given absolute
        cores = sorted([int(i) for i in line.split(",") if not self._bPhysical or int(i) in self._cpus.keys()])
      
      self._placement.append(cores)
  
  def _print_system_info(self):
    sHyperthreadMode = "on" if not self._bPhysical else "off"
    iPhysicalCoreCount = len(self._cpus.keys())
    sPhysicalCores = ",".join([str(i) for i in sorted(self._cpus.keys())])
    iHyperthreadCount = len(self._hyperthreads.keys())
    sLogicalCores = ",".join([str(i) for i in sorted(self._hyperthreads.keys())])

    print("CPU setup [hyperthreading = %s]:" % (sHyperthreadMode))
    print("  %d Physical Cores\t: %s" % (iPhysicalCoreCount, sPhysicalCores))

    if not self._bPhysical:
      print("  %d Logical Cores\t: %s" % (iHyperthreadCount, sLogicalCores))

    for (id, node) in enumerate(self._placement):
      print("  NUMA Node %d\t\t: %s" % (id, ",".join([str(n) for n in node])))


  def __init__(self, bPhysical):
    self._current_node = 0
    self._current_core = 0

    self._bPhysical = bPhysical
    self._basepath = "/sys/devices/system/cpu/"
    self._siblings = "/topology/thread_siblings_list"
    self._cpus = {}
    self._hyperthreads = {}
    self._placement = []  

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
  
  def _cpu_file(self, iCoreId, value):
    try:
      sPath = self._cpus[iCoreId]
    except KeyError:
      sPath = self._hyperthreads[iCoreId]
    

    with open(sPath + "/online", "w") as cpu_file:
      print(value, file=cpu_file)

  def disable(self, iCoreId = -1, all = False):
    to_disable = None

    if iCoreId >= 0 and all == False:
      to_disable = [iCoreId]
    elif all == True:
      to_disable = sorted(self._cpus.keys())[1:]

    for i in to_disable:
      self._cpu_file(i, "0")    

  def enable(self, iCoreId):
    if iCoreId > 0:
      self._cpu_file(iCoreId, "1")  

def main():
  if os.geteuid() != 0:
    exit("""
     You need to have root privileges to run this tool.
     Exiting.
    """)

  parser = argparse.ArgumentParser()
  parser.add_argument('-p', '--physical', dest='physical', action='store_true')
  args = parser.parse_args()

  with HardwareThreading(args.physical) as cores:
    cores.disable(all = True)

    for core in cores:
      cores.enable(core)

if __name__ == "__main__": main()