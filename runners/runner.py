import os
import stat
import subprocess
import datetime
from pathlib import Path  

class BenchmarkRunner:
  def __init__(self, sName, sPath):
    self._executables = []
    self._name = sName
    self._timestamp = datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')
    self._get_executables(sPath)
    
  def _get_executables(self, sPath):
    executable = stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH

    for sFilename in os.listdir(sPath):
      sFilepath = sPath + sFilename if sPath[-1] == "/" else sPath + "/" + sFilename
      
      if os.path.isfile(sFilepath):
        st = os.stat(sFilepath)
        mode = st.st_mode
        if mode & executable:
            self._executables.append(sFilepath)

  def _create_directory(self):
    sPath = "output/" + self._name + "/" + self._timestamp
    os.makedirs(sPath, exist_ok=True)

    return sPath + "/"

  def execute(self):
    sPath = self._create_directory()

    for exe in self._executables:
      with open(sPath + Path(exe).name + ".txt", "w+") as outputfile:
        bench = subprocess.Popen([exe], stdout=outputfile)
        bench.wait()
