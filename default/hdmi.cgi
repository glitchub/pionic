#!/usr/bin/python3 -u
# write image to hdmi via dispmanx

import os, sys, subprocess, PIL.Image as Image

# directory containing this file should also contain colorbars.jpg
here = os.path.dirname(__file__)

dispmanx=os.environ["PIONIC"]+"/dispmanx/dispmanx"
if not os.path.isfile(dispmanx): raise Exception("Need executable "+dispmanx)

timeout = 0
display = "HDMI"

for o in sys.argv[1:]:
    opt,_,arg = o.partition('=')
    if   opt == "timeout": timeout=int(arg)
    elif opt == "lcd":     display="LCD"
    else: raise Exception("Unexpected argument %s" % o)

# always kill an existing process
subprocess.run(["pkill","dispmanx"])

# Get display list from tvservice
# Hopeful the output format won't change
number=None
for s in subprocess.check_output(["tvservice","-l"]).decode("ascii").splitlines()[1:]:
    if display in s:
        number=int(s.split()[2][0])
        break
if number is None: raise Exception("Can't find %s display" % display)

resolution=subprocess.check_output([dispmanx, "-rd%d" % number]).decode("ascii")
if not resolution: raise Exception("Can't get dispmanx resolution for device %d" % number)
resolution = [int(n) for n in resolution.split("x")]

if int(os.environ.get("CONTENT_LENGTH",0)):
    image = Image.open(sys.stdin.buffer)
else:
    image = Image.open(here+"/colorbars.jpg")

image = image.resize(resolution).convert("RGB")

if not os.fork():
    # child, close inherited file handles
    for fd in os.listdir("/proc/self/fd"):
        try: os.close(int(fd))
        except: pass

    # run dispmanx and pass rgb data to its stdin, it stays resident
    dm = subprocess.Popen([dispmanx, "-t%d" % timeout, "-d%d" % number], stdin=subprocess.PIPE)
    dm.stdin.write(image.tobytes())
    dm.stdin.close()
