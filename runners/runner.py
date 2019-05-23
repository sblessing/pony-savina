import os
import stat
import subprocess
import datetime
from pathlib import Path  

# java -cp Executable
# pony-savina -l -> [...] -> pony-savina -b=<list-item>

class ExecutableRunner:
  def __init__(self):
    self._name = None
    self._timestamp = datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')
    self._executables = []
    self._iterator = None
  
  def _get_executables(self, sPath):
    executable = stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH

    if not os.path.isfile(sPath):
      for sFilename in os.listdir(sPath):
        sFilepath = sPath + sFilename if sPath[-1] == "/" else sPath + "/" + sFilename
      
        if os.path.isfile(sFilepath):
          if os.stat(sFilepath).st_mode & executable:
            self._executables.append(sFilepath)
    else:
      self._executables.append(sPath)

    self._iterator = iter(self._executables)

  def __iter__(self):
    return self._iterator

  def __next__(self):
    sPath = next(self._iterator)

    return (sPath, Path(sPath).name)

  def _create_directory(self, cores):
    sPath = "output/" + self._name + "/" + self._timestamp + "/" + str(cores)
    os.makedirs(sPath, exist_ok=True)

    return sPath + "/"

  def initialize(self, sName, sPath):
    self._name = sName
    self._get_executables(sPath)

  def execute(self, cores):
    sPath = self._create_directory(cores)

    for (exe, output) in self:
      with open(sPath + output + ".txt", "w+") as outputfile:
        bench = subprocess.Popen([exe], stdout=outputfile)
        bench.wait()

class BenchmarkRunner:
  def __init__(self, decorated):
    self._decorated = decorated

  def __call__(self):
    raise TypeError('The benchmark runner must be accessed through `instance()`.')

  def __instancecheck__(self, inst):
    return isinstance(inst, self._decorated)

  def instance(self):
    try:
      return self._instance
    except AttributeError:
      self._instance = self._decorated()
      return self._instance   