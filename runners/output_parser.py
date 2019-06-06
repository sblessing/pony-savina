import re

class PonyOutputParser:
  def __init__(self, files):
    self._files = files

  def parse(self, cores, results):
    for file in self._files:
      with open(file, "r") as bench:
        for line in bench:
          components = line.split(",")
          results[components[0]][cores - 1] = float(components[1])

class SavinaOutputParser:
  def __init__(self, files):
    self._files = files

  def parse(self, cores, results):
    name_pattern = re.compile("(?<=Benchmark: ).*$", re.MULTILINE)
    median_pattern = re.compile("(?<=Median:).*[0-9]+.[0-9]+", re.MULTILINE)

    for file in self._files:
      with open(file, "r") as bench:
        data = ''.join(line for line in bench)
        
        name = re.search(name_pattern, data)
        median = re.search(median_pattern, data)

        if name and median:
          results[name.group()][cores - 1] = float(median.group())