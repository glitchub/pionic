# Pi-based Networked Instrument Controller

ifneq (${USER},root)
# become root if not already
default ${MAKECMDGOALS}:; sudo -E ${MAKE} ${MAKECMDGOALS}
else
# this is undefined by the clean and uninstall targets
INSTALL=1

SHELL=/bin/bash

ifeq ($(shell grep Raspbian.*buster /etc/os-release),)
    $(error Requires raspbian version 10)
endif

# Load the configuration file
include pionic.cfg
override LAN_IP:=$(strip ${LAN_IP})
override FORWARD:=$(strip ${FORWARD})
override UNBLOCK:=$(strip ${UNBLOCK})
override DHCP_RANGE:=$(strip ${DHCP_RANGE})
override BEACON:=$(strip ${BEACON})
override SPI:=$(strip ${SPI})
override I2C:=$(strip ${I2C})
override PRODUCTION:=$(strip ${PRODUCTION})

ifndef LAN_IP
$(error Must define LAN_IP)
endif

ifdef SERVER_IP
# Forward 61080 and 61443 to the factory server
FORWARD += 61080=${SERVER_IP}:80 61443=${SERVER_IP}:443 # forward from DUT to server
endif

# Always unblock SSH
UNBLOCK += 22

# git repos to fetch and build, note the ":" must be escaped
REPOS += "https\://github.com/glitchub/rasping ; make UNBLOCK='${UNBLOCK}' LAN_IP=${LAN_IP} FORWARD='${FORWARD}' DHCP_RANGE='${DHCP_RANGE}' PINGABLE=yes"
REPOS += "https\://github.com/glitchub/runfor ; make"
REPOS += "https\://github.com/glitchub/pifm ; make"
REPOS += "https\://github.com/glitchub/plio ; make"
REPOS += "https\://github.com/glitchub/evdump ; make"
REPOS += "https\://github.com/glitchub/fbtools ; make"

# apt packages to install
PACKAGES += sox omxplayer python-pgmagick

# files to be tweaked
FILES=/etc/rc.local /boot/config.txt /etc/hosts

# function to invoke raspi-config in non-interactive mode, "on" enables, any other disables
raspi-config=raspi-config nonint $1 $(if $(filter on,$2),0,1)

# function to invoke apt
APT=DEBIAN_FRONTEND=noninteractive apt

.PHONY: default clean packages repos files

ifdef INSTALL
# default, install files
default: files
ifdef SPI
	$(call raspi-config,do_spi,${SPI})
endif
ifdef I2C
	$(call raspi-config,do_i2c,${I2C})
endif
ifdef PRODUCTION
	@echo "Syslog disabled in production mode"
	systemctl disable --now rsyslog
endif
	sync
	@echo "Reboot to start pionic"
endif

# files depend on repos
.PHONY: ${FILES}
files: ${FILES}
${FILES}: repos

# repos depend on packages
# The install logic is all in bash, because we must expand the quoted repo names
repos: packages
	repos=(${REPOS}); \
	for r in "$${repos[@]}"; do \
	    u=$${r%%;*}; m=$${r#*;}; d=$${u#**/};
	    if ! [[ -d $$d ]]; then \
	        git clone $$url || exit 1; \
		if [[ $$m ]]; then \
		    cd $$dir ; $$make || exit 1; cd ..; \
		fi; \
	    fi; \
	done

# install packages with apt
packages:; ${APT} install -y ${PACKAGES}

else
# uninstall files
default: ${FILES}
# disable SPI and I2C if we enabled it
ifdef SPI
	$(call raspi-config,do_spi,off)
endif
ifdef I2C
	$(call raspi-config,do_i2c,off)
endif
	systemctl enable --now rsyslog

# add "pionic.server" host entry for DUT
/etc/hosts:
	sed -i '/pionic start/,/pionic end/d' $@
ifdef INSTALL
	echo "# pionic start" >> $@
	echo "${LAN_IP}\\tpionic.server" >> $@
	echo "# pionic end" >> $@
endif

# auto-start pionic.sh
/etc/rc.local:
	sed -i '/pionic/d' $@
ifdef INSTALL
ifndef SERVER_IP
	sed -i '/^exit/i/home/pi/pionic/pionic.sh start local' $@
else
	sed -i '/^exit/i/home/pi/pionic/pionic.sh start' $@
endif
endif

# configure kernel
/boot/config.txt:
	sed -i '/pionic start/,/pionic end/d' $@
ifdef INSTALL
ifdef SERVER_IP
	echo "# pionic start" >> $@
	echo "[all]" >> $@
	echo "hdmi_force_hotplug=1" >> $@
	echo "hdmi_group=1" >> $@
	echo "hdmi_mode=16 # 1920x1080" >> $@
	echo "hdmi_blanking=0" >> $@
	echo "hdmi_ignore_edid=0x5a000080" >> $@
	echo "gpu_mem=64" >> $@
	echo "# avoid_warnings=1" >> $@
	echo "overscan_left=-32" >> $@
	echo "overscan_right=-32" >> $@
	echo "overscan_top=-32" >> $@
	echo "overscan_bottom=-32" >> $@
	echo "# pionic end" >> $@
endif
endif

# Clean config files but don't remove packages or repos
clean:
	make INSTALL=
	@echo "Clean complete"

# Clean config files and remove packages and repos
uninstall:
	make INSTALL=
	repos=(${REPOS}); \
	for r in "$${repos[@]}"; do \
	    u=$${r%%;*}; d=$${g##*/}; \
	    rm -rf $$d; \
	done
	${APT} remove --autoremove --purge -y ${packages}
	@echo "Uninstall complete"
