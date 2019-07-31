Pionic - PI-based Networked Instrument Controller

Physical configuration:

    The network interface connects to the factory subnet and receives an
    address via DHCP. The DHCP server is configured to assign a specific IP
    address for the PI's MAC, presumably correlates to the test station ID.

    A USB ethernet dongle attaches to the DUT and gets a static IP (defined in the Makefile 
    pionic.cfg).

    The 40-pin I/O connector attaches to test instrumentation, which is
    customized for the specific test station requires and not in scope of this
    document.

    An "official" 7-inch touchscreen (attaches to the RPi display connector,
    NOT to HDMI).

Pionic provides:

    NAT translation from the DUT to the server. Port 61080 is forwarded to
    factory server port 80, and 61443 is forwarded to factory server port 443,
    the DUT only has to know the IP address of the pionic device.

    If enabled, the beacon server is started on the DUT interface, this
    transmits "beacon ethernet packets. The DUT listens for beacons during
    boot, if detected then it enters factory diagnostic mode and brings up
    pre-defined static IP in the same subnet.

    Alternatively if the DUT will automatically bring up static IP during boot,
    it can simply attempt to access the factory server at port 61080, if the
    expected response is received then it enters diagnostic mode.

    Access to test-specific CGI's on port 80, the DUT uses curl e.g.:

        curl -f http://172.31.255.1/gpio?14=1

    User interface via the touchscreen display. 

    Customizable test fixture support.
    
To install:

    Download the SDcard image:
    
        wget https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-06-24/2019-06-20-raspbian-buster-lite.zip

    Unzip and extract file 2019-06-20-raspbin-buster-lite.img (about 1.8GB). 

    Copy the img file to an 8GB SDcard using dd on linux or Win32DiskImager
    on Windows.

    Insert the card into the RPi, attach display or monitor and usb keyboard,
    attach ethernet. It should boot to a text console (if it boots to X, you
    have the wrong image).  Log in as user 'pi', password 'raspberry'

    Run:
        sudo apt update
        sudo apt upgrade
        sudo apt install git
        git clone https://github.com/glitchub/pionic

    Review the "USER CONFIGURATION" section in the Makefile. Then:

        make -C pionic

    Ensure that USB dongle is attached and reboot. Pi will boot to pionic.sh
    which takes over the display and shows status. If all is well pionic.sh
    will start the fixture driver.

    When pionic is running it takes over the display, login is normally only
    possible via ssh. It's possible to induce pionic failure by booting with
    the ethernet unplugged and therefore access the console while it's trying
    to start.
