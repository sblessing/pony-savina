import os
import stat

class BenchmarkRunner:
  def __init__(self, sPath):
    self._executables = []

    self._get_executables(sPath)
    
  def _get_executables(self, sPath):
    executable = stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH

    for sFilename in os.listdir('./' + sPath):
      if os.path.isfile(sFilename):
        st = os.stat(sFilename)
        mode = st.st_mode
        if mode & executable:
            sFullpath = sPath + sFilename if sPath[-1] == "/" else sPath + "/" + sFilename
            self._executables.append(sFullpath)

  def execute(self):
    for exe in self._executables:
      print(exe)