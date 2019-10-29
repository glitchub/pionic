#!/usr/bin/python

#!/usr/bin/python

# Test fixture control cgi. Given argument XXX and list of options, execute
# "do_XXX(options)". If the return value is not None, print it to stdout.

import os,sys
sys.path.append(os.environ['PIONIC']+'/plio')
from gpio_sysfs import gpio
from i2c_tmp101 import tmp101

# gpio class, inherit existing params
gpio.default = None

# configure IO's, return gpio7 state
def do_init():
    gpio(5,output=True, invert=False, state=False)
    gpio(6, output=True, invert=False, state=False)
    gpio(7, output=False, invert=True)
    tmp101(1,0x49).set_resolution(3)

def do_gpios(state):
    gpio(5).set_output(state & 1)
    gpio(6).set_output(state & 2)
    return gpio(7).state

def do_get_temp():
   print tmp101(1,0x49).get_temperature()

# invoke the requested function
exec "ret=do_"+sys.argv[1]+"("+",".join(sys.argv[2:])+")"
if ret is not None: print ret

