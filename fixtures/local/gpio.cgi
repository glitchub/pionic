#!/usr/bin/python

# gpio cgi requires one or more args in form:
#
#   X=0 or X=1 - set gpio X as output, in state 0 or 1
#   X          - set gpio X as input and return current state
#   X@         - return current state of gpio X whether it's an input or an output (without changing it)
#
# gpio states are returned as '0' or '1', on a single line in the order requested

import os, sys, re
sys.path.append(os.environ['PIONIC']+'/plio')
from gpio_sysfs import gpio

states=[]

for i in sys.argv[1:]:
    r=re.match('(\d+)=([01])$',i)
    if r:
        N,S=map(int, r.groups())
        g=gpio(N, output=True, state=bool(S))
        del(g)
        continue;

    # <gpio
    r=re.match('(\d+)$',i)
    if r:
        N=int(r.groups()[0])
        g=gpio(N, output=False)
        states.append(1 if g.state else 0)
        del(g)
        continue;

    # gpio?
    r=re.match('(\d+)@$',i)
    if r:
        # return gpio current state without changing it
        N=int(r.groups()[0])
        g=gpio(N, output=None, state=None)
        states.append(1 if g.state else 0)
        del(g)
        continue;

    raise Exception("Invalid gpio operation '"+i+"'")

if states: print " ".join(map(str,states))
