# Pi-based Networked Instrument Controller

#### USER CONFIGURATION

# Factory server IP address, transmitted by beacon or returned by cgi/factory
SERVER_IP=172.16.240.254

# LAN IP address, i.e. what address the DUT expects to talk to
LAN_IP=192.168.111.1

# TCP ports to be forwarded from PI WAN interface to specific DUTS, comment out if none
FORWARD=2222=192.168.111.10:22

# If set (to anything), install beacon daemon. Comment out if DUTs have static IP
# BEACON=1

# Specify test fixture driver, typically set the 'none' to skip the fixture
# download entirely. Comment out the let pionic get the fixture from the database.
FIXTURE=none

#### END USER CONFIGURATION

# Make sure we're running the right code and are not root
ifeq ($(shell grep "Raspberry Pi reference 2019-06-20" /etc/rpi-issue),)
$(error "Requires Raspberry Pi running 2019-06-20-raspbin-buster-lite.img")
endif

ifneq ($(filter root,${USER}),)
$(error Must not be run as root))
endif

# git repos to fetch and build, note the ":" must be escaped
repos=https\://github.com/glitchub/rasping
repos+=https\://github.com/glitchub/evdump
repos+=https\://github.com/glitchub/runfor
repos+=https\://github.com/glitchub/fbput
repos+=https\://github.com/glitchub/FM_Transmitter_RPi3
repos+=https\://github.com/glitchub/i2cio
ifdef BEACON
repos+=https\://github.com/glitchub/beacon
endif

# apt packages to install
packages=sox graphicsmagick omxplayer

# files to be tweaked
files=/etc/rc.local /boot/config.txt

# rebuild everything
.PHONY: default clean packages ${repos} ${files}

default: packages ${repos} ${files}
ifndef CLEAN
	sudo systemctl enable ssh
	sync
	@echo "Reboot to start pionic"
endif

# install and build repos
${repos}: packages
ifndef CLEAN
	[ -d $(notdir $@) ] || git clone $@
	make -C $(notdir $@)
	$(if $(findstring rasping,$@),WAN_IP= DHCP_RANGE= UNBLOCK=22 LAN_IP=${LAN_IP} FORWARD=${FORWARD})
else
	make -C $(notdir $@) clean || true
	rm -rf $(notdir $@)
endif

# install packages
APT=DEBIAN_FRONTEND=noninteractive sudo -E apt
packages:
ifndef CLEAN
	${APT} install -y ${packages}
else
	${APT} remove --autoremove --purge -y ${packages}
endif

# auto-start pionic.sh, pass it the factory server IP address
/etc/rc.local:
	sudo sed -i '/pionic/d' $@ # first delete the old
ifndef CLEAN
	sudo sed -i '/^exit/i/home/pi/pionic/pionic.sh start ${SERVER_IP} ${FIXTURE}' $@
endif

# configure kernel
/boot/config.txt:
	sudo sed -i '/pionic start/,/pionic end/d' $@ # first delete the old
ifndef CLEAN
	printf "\
# pionic start\n\
[all]\n\
hdmi_force_hotplug=1\n\
hdmi_group=1\n\
hdmi_mode=16 # 1920x1080\n\
hdmi_blanking=0\n\
hdmi_ignore_edid=0x5a000080\n\
dtparam=i2c_arm=on\n\
dtparam=spi=on\n\
gpu_mem=16\n\
avoid_warnings=1\n\
overscan_left=-32\n\
overscan_right=-32\n\
overscan_top=-32\n\
overscan_bottom=-32\n\
# pionic end\n\
" | sudo sh -c 'cat >> $@'
endif

# Try to delete everything back to original state
clean:
	make CLEAN=1
	@echo "All clean"
