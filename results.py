if __name__ == "__main__":
  sums = {}

  for line in open("benchmarks.log", "r"):
    parts = line.split(",")
    key = parts[1] + "," + parts[2]
    value = float(parts[3])

    if key not in sums.keys():
      sums[key] = []

    sums[key].append(value)

  for result in sums.keys():
    print(result + "," + str(sum(sums[result])/len(sums[result])))
    
