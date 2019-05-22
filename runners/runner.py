import os
import stat

class BenchmarkRunner:
  def __init__(self, sPath):
    self._executables = []

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

  def execute(self):
    for exe in self._executables:
      print(exe)
