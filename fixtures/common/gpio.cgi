#!/usr/bin/python

# Raspberry Pi GPIO control, expects one or more args in form:
#
#   X=0 or X=1 - set gpio X as output, in state 0 or 1
#   X          - set gpio X as input and return current state
#   X@         - return current state of gpio X whether it's an input or an output (without changing it)
#
# States are returned as '0' or '1', on a single line in the order requested.
#
# Note the gpios are specified using Pi connector PIN numbers, not the actual
# SOC GPIO numbers. Starred pins may be unavailable due to alternate function.
#
#                +-----+               *GPIO_0  : ID_SD (never available)
#        3.3V   1|     |2   5V         *GPIO_1  : ID_SC (never available)
#      GPIO_2   3|*    |4   5V         *GPIO_2  : I2C SDA
#      GPIO_3   5|*    |6   GND        *GPIO_3  : I2C SCL
#      GPIO_4   7|*   *|8   GPIO_14    *GPIO_4  : GPCLK0 (used by mkfm)
#         GND   9|    *|10  GPIO_15    *GPIO_5  : GPCLK1
#     GPIO_17  11|*   *|12  GPIO_18    *GPIO_6  : GPCLK2
#     GPIO_27  13|     |14  GND        *GPIO_7  : SPI0 CE1
#     GPIO_22  15|     |16  GPIO_23    *GPIO_8  : SPI0 CE0
#        3.3V  17|     |18  GPIO_24    *GPIO_9  : SPI0 MISO
#     GPIO_10  19|*    |20  GND        *GPIO_10 : SPI0 MOSI
#      GPIO_9  21|*    |22  GPIO_25    *GPIO_11 : SPI0 SCLK
#     GPIO_11  23|*   *|24  GPIO_8     *GPIO_12 : PWM0
#         GND  25|    *|26  GPIO_7     *GPIO_13 : PWM1
#      GPIO_0  27|*   *|28  GPIO_1     *GPIO_14 : UART TX
#      GPIO_5  29|*    |30  GND        *GPIO_15 : UART RX
#      GPIO_6  31|*   *|32  GPIO_12    *GPIO_16 : SPI1 CE2
#     GPIO_13  33|*    |34  GND        *GPIO_17 : SPI1 CE1
#     GPIO_19  35|*    |36  GPIO_16    *GPIO_18 : SPI1 CE0
#     GPIO_26  37|    *|38  GPIO_20    *GPIO_19 : SPI1 MISO
#         GND  39|    *|40  GPIO_21    *GPIO_20 : SPI1 MOSI
#                +-----+               *GPIO_21 : SPI1 SCLK

import os, sys, re
sys.path.append(os.environ['PIONIC']+'/plio')
from gpio_sysfs import gpio

# Map header pins to SOC GPIOs
# Unavailable GPIOS are commented out.
pinmap = {
  # PIN   GPIO
  # 27  :  0,
  # 28  :  1,
    3   :  2,
    5   :  3,
    7   :  4,
    8   :  14,
    10  :  15,
    11  :  17,
    12  :  18,
    13  :  27,
    15  :  22,
    16  :  23,
    18  :  24,
    19  :  10,
    21  :  9,
    22  :  25,
    23  :  11,
    24  :  8,
    26  :  7,
    29  :  5,
    31  :  6,
    32  :  12,
    33  :  13,
    35  :  19,
    36  :  16,
    37  :  26,
    38  :  20,
    40  :  21
}

# return gpio for specified pin
def lookup(pin):
    pin=int(pin)
    if not pin in pinmap.keys():
        raise Exception("Invalid gpio %d" % pin)
    return pinmap[pin]

# list of states to print on exit
states=[]

for i in sys.argv[1:]:
    r=re.match('(\d+)=([01])$',i)
    if r:
        # set gpio as output
        g=gpio(lookup(r.groups()[0]), output=True, state=int(r.groups()[1]))
        del(g)
        continue;

    r=re.match('(\d+)$',i)
    if r:
        # set gpio as input and return state
        g=gpio(lookup(r.groups()[0]), output=False)
        states.append(g.state)
        del(g)
        continue;

    r=re.match('(\d+)@$',i)
    if r:
        # return gpio current state without changing it
        g=gpio(lookup(r.groups()[0]), output=None, state=None)
        states.append(g.state)
        del(g)
        continue;

    raise Exception("Invalid gpio operation '"+i+"'")

if states: print " ".join(map(lambda s:1 if s else 0,states))
