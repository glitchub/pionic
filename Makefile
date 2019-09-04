# Pi-based Networked Instrument Controller

#### USER CONFIGURATION

# Factory server IP address
SERVER_IP = 172.16.240.254

# LAN IP address, i.e. what address the DUT expects to talk to
LAN_IP = 192.168.111.1

# Space-separated list of TCP ports to be forwarded to specific hosts (in either direction).
# Ports 61080 and 61433 must be defined and forward to the server. Others are optional.
FORWARD = 61080=${SERVER_IP}:80 61443=${SERVER_IP}:443
FORWARD += 2222=192.168.111.10:22

# Space-separated list of WAN ports to unblock, at least allow ssh port 22
UNBLOCK = 22

# IP range to be assigned by dhcp, in the form "firstIP, lastIP". Comment out to disable.
DHCP_RANGE = 192.168.111.250, 192.168.111.254

# If set (to anything), install beacon daemon. Comment out if DUTs have static IP
# BEACON = 1

#### END USER CONFIGURATION

# Make sure we're running the right code and are not root
ifeq ($(shell grep "Raspberry Pi reference 2019-06-20" /etc/rpi-issue),)
$(error "Requires Raspberry Pi running 2019-06-20-raspbin-buster-lite.img")
endif

ifeq (${USER},root)
$(error Must not be run as root))
endif

# git repos to fetch and build, note the ":" must be escaped
repos=https\://github.com/glitchub/rasping
repos+=https\://github.com/glitchub/evdump
repos+=https\://github.com/glitchub/runfor
repos+=https\://github.com/glitchub/fbput
repos+=https\://github.com/glitchub/pifm
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
	if [ -d $(notdir $@) ]; then git -C $(notdir $@) pull; else git clone $@; fi
	make -C $(notdir $@) $(if $(findstring rasping,$@),UNBLOCK="$(strip ${UNBLOCK})" LAN_IP="$(strip ${LAN_IP})" FORWARD="$(strip ${FORWARD})" DHCP_RANGE="$(strip ${DHCP_RANGE})")
else
	make -C $(notdir $@) clean || true
ifeq (${CLEAN},2)
	rm -rf $(notdir $@)
endif
endif

# install packages
APT=DEBIAN_FRONTEND=noninteractive sudo -E apt
packages:
ifndef CLEAN
	${APT} install -y ${packages}
else ifeq (${CLEAN},2)
	${APT} remove --autoremove --purge -y ${packages}
endif

# auto-start pionic.sh
/etc/rc.local:
	sudo sed -i '/pionic/d' $@ # first delete the old
ifndef CLEAN
	sudo sed -i '/^exit/i/home/pi/pionic/pionic.sh start' $@
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

# Clean config files but don't remove packages or repos
clean:
	make CLEAN=1
	@echo "Clean complete"

# Clean config files and remove packages and repos
uninstall:
	make CLEAN=2
	@echo "Uninstall complete"
