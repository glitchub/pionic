# Pi-based Networked Instrument Controller

# Make sure we're running on a Pi
ifeq ($(wildcard /etc/rpi-issue),)
$(error Must be run on Raspberry Pi)
endif

ifeq (${USER},root)
$(error Must not be run as root))
endif

# Load the configuration file
include pionic.cfg

LAN_IP:=$(strip ${LAN_IP})
ifeq (${LAN_IP},)
$(error Must define LAN_IP)
endif

SERVER_IP:=$(strip ${SERVER_IP})
ifdef CLEAN
# force full clean
SERVER_IP=xxx
BEACON=on
endif

ifneq (${SERVER_IP},)
# Forward 61080 and 61443 to the factory server
FORWARD += 61080=${SERVER_IP}:80 61443=${SERVER_IP}:443 # forward from DUT to server
endif

# Always unblock SSH
UNBLOCK += 22

LAN_IP:=$(strip ${LAN_IP})
FORWARD:=$(strip ${FORWARD})
UNBLOCK:=$(strip ${UNBLOCK})
DHCP_RANGE:=$(strip ${DHCP_RANGE})
BEACON:=$(strip ${BEACON})
SPI:=$(strip ${SPI})
I2C:=$(strip ${I2C})

# invoke raspi-config in non-interactive mode, "on" enables, any other disables
raspi-config=sudo raspi-config nonint $1 $(if $(filter on,$2),0,1)

# git repos to fetch and build, note the ":" must be escaped
repos=https\://github.com/glitchub/rasping
repos+=https\://github.com/glitchub/runfor
repos+=https\://github.com/glitchub/pifm
repos+=https\://github.com/glitchub/plio
ifneq (${SERVER_IP},)
repos+=https\://github.com/glitchub/evdump
repos+=https\://github.com/glitchub/fbtools
endif
ifeq (${BEACON},on)
repos+=https\://github.com/glitchub/beacon
endif

# apt packages to install
packages=sox
ifneq (${SERVER_IP},)
packages+=omxplayer python-pgmagick
endif

# files to be tweaked
files=/etc/rc.local /boot/config.txt /etc/hosts

# rebuild everything
.PHONY: default clean packages ${repos} ${files}

default: packages ${repos} ${files}
ifdef CLEAN
# disable SPI and I2C if we enabled it
ifdef SPI
	$(call raspi-config,do_spi,off)
endif
ifdef I2C
	$(call raspi-config,do_i2c,off)
endif
else
# maybe enable SPI and I2C via raspi-config
ifdef SPI
	$(call raspi-config,do_spi,${SPI})
endif
ifdef I2C
	$(call raspi-config,do_i2c,${I2C})
endif
	sync
	@echo "Reboot to start pionic"
endif

# install and build repos
${repos}: packages
ifndef CLEAN
	if [ -d $(notdir $@) ]; then git -C $(notdir $@) pull; else git clone $@; fi
	! [ -f $(notdir $@)/Makefile ] || make -C $(notdir $@) $(if $(findstring rasping,$@),UNBLOCK="${UNBLOCK}" LAN_IP="${LAN_IP}" FORWARD="${FORWARD}" DHCP_RANGE="${DHCP_RANGE}")
else
	! [ -f $(notdir $@)/Makefile ] || make -C $(notdir $@) clean || true
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

# add "pionic" host entry for DUT
/etc/hosts:
	sudo sed -i '/pionic start/,/pionic end/d' $@ # first delete the old
ifndef CLEAN
	printf "\
# pionic start\n\
${LAN_IP}\\tpionic\n\
# pionic end\n\
" | sudo sh -c 'cat >> $@'
endif

# auto-start pionic.sh
/etc/rc.local:
	sudo sed -i '/pionic/d' $@ # first delete the old
ifndef CLEAN
ifeq (${SERVER_IP},)
	sudo sed -i '/^exit/i/home/pi/pionic/pionic.sh start local' $@
else
	sudo sed -i '/^exit/i/home/pi/pionic/pionic.sh start' $@
endif
endif

# configure kernel
/boot/config.txt:
	sudo sed -i '/pionic start/,/pionic end/d' $@ # first delete the old
ifndef CLEAN
ifneq (${SERVER_IP},)
	printf "\
# pionic start\n\
[all]\n\
hdmi_force_hotplug=1\n\
hdmi_group=1\n\
hdmi_mode=16 # 1920x1080\n\
hdmi_blanking=0\n\
hdmi_ignore_edid=0x5a000080\n\
gpu_mem=64\n\
# avoid_warnings=1\n\
overscan_left=-32\n\
overscan_right=-32\n\
overscan_top=-32\n\
overscan_bottom=-32\n\
# pionic end\n\
" | sudo sh -c 'cat >> $@'
endif
endif

# Clean config files but don't remove packages or repos
clean:
	make CLEAN=1
	@echo "Clean complete"

# Clean config files and remove packages and repos
uninstall:
	make CLEAN=2
	@echo "Uninstall complete"
