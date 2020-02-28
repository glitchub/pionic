#!/usr/bin/python

# Raspberry Pi GPIO control, expects one or more args in form:
#
#   X=0 or X=1 - set gpio X as output, in state 0 or 1
#   X          - set gpio X as input and return current state
#   X@         - return current state of gpio X whether it's an input or an output (without changing it)
#
# States are returned as '0' or '1', on a single line in the order requested.
#
#                +-----+
#        3.3V   1|     |2   5V
#      GPIO_2   3|*    |4   5V
#      GPIO_3   5|*    |6   GND
#      GPIO_4   7|*   *|8   GPIO_14
#         GND   9|    *|10  GPIO_15
#     GPIO_17  11|*   *|12  GPIO_18
#     GPIO_27  13|     |14  GND
#     GPIO_22  15|     |16  GPIO_23
#        3.3V  17|     |18  GPIO_24
#     GPIO_10  19|*    |20  GND
#      GPIO_9  21|*    |22  GPIO_25
#     GPIO_11  23|*   *|24  GPIO_8
#         GND  25|    *|26  GPIO_7
#      GPIO_0  27|*   *|28  GPIO_1
#      GPIO_5  29|*    |30  GND
#      GPIO_6  31|*   *|32  GPIO_12
#     GPIO_13  33|*    |34  GND
#     GPIO_19  35|*    |36  GPIO_16
#     GPIO_26  37|    *|38  GPIO_20
#         GND  39|    *|40  GPIO_21
#                +-----+

import os, sys, re
sys.path.append(os.environ['PIONIC']+'/plio')
from gpio_sysfs import gpio

# check gpio is valid
def valid(gpio):
    gpio=int(gpio)
    if gpio < 2 or gpio > 27:
        raise Exception("Invalid gpio %d" % gpio)
    return gpio

# list of states to print on exit
states=[]

for i in sys.argv[1:]:
    r=re.match('(\d+)=([01])$',i)
    if r:
        # set gpio as output
        g=gpio(valid(r.groups()[0]), output=True, state=int(r.groups()[1]))
        del(g)
        continue;

    r=re.match('(\d+)$',i)
    if r:
        # set gpio as input and return state
        g=gpio(valid(r.groups()[0]), output=False)
        states.append(g.state)
        del(g)
        continue;

    r=re.match('(\d+)@$',i)
    if r:
        # return gpio current state without changing it
        g=gpio(valid(r.groups()[0]), output=None, state=None)
        states.append(g.state)
        del(g)
        continue;

    raise Exception("Invalid gpio operation '"+i+"'")

if states: print " ".join(map(lambda s:1 if s else 0,states))
