#!/usr/bin/python3
# write image to hdmi via dispmanx

import os, sys, subprocess, pgmagick as gm

# directory containing this file should also contain colorbars.jpg
here = os.path.dirname(__file__)

dispmanx=os.environ["PIONIC"]+"/dispmanx/dispmanx"
if not os.path.isfile(dispmanx): raise Exception("Need executable "+dispmanx)

timeout = 30
display = "HDMI"

for o in sys.argv[1:]:
    opt,_,arg = o.partition('=')
    if   opt == "timeout": timeout=int(arg or 30)
    elif opt == "lcd":     display="LCD"
    else: raise Exception("Unexpected argument %s" % o)

services=subprocess.check_output(["tvservice","-l"]).decode("ascii").splitlines()[1:]

number=None
for s in services:
    if display in s:
        number=int(s.split()[2][0])
        break
if number is None: raise Exception("Can't find %s display" % display)

resolution=subprocess.check_output([dispmanx, "-rd%d" % number]).decode("ascii")
if not resolution: raise Exception("Can't get dispmanx resolution for device %d" % number)

if os.environ.get("CONTENT_LENGTH"):
    image = gm.Image(gm.Blob(sys.stdin.buffer.read()))
else:
    image = gm.Image(here+"/colorbars.jpg")

image.resize("!"+resolution)
blob = gm.Blob();
image.write(blob, "RGB", 8)

dm = subprocess.Popen([dispmanx, "-t%d" % timeout, "-d%d" % number], stdin=subprocess.PIPE)
dm.stdin.write(blob.data)
dm.stdin.close()
