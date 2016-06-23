#! /usr/bin/env python

filename = '/cvmfs/atlas.cern.ch/repo/ATLASLocalRootBase/RELEASE.NOTES'

n = 10
print str(n) + " first lines of:\n" + filename

i = 0
file = open(filename)
for line in file:
    print line,
    i += 1
    if i > n:
        break

