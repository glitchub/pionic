# Pi-based Networked Instrument Controller

ifneq (${USER},root)
# become root if not already
.PHONY: default ${MAKECMDGOALS}
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
LAN_IP:=$(strip ${LAN_IP})
SERVER_IP:=$(strip ${SERVER_IP})

SPI:=$(strip ${SPI})
I2C:=$(strip ${I2C})
PRODUCTION:=$(strip ${PRODUCTION})
HDMI_GROUP:=$(strip ${HDMI_GROUP})
HDMI_MODE:=$(strip ${HDMI_MODE})

ifdef LAN_IP
# Install rasping if LAN_IP is enabled, these are the parameters it requires
ifdef SERVER_IP
# Forward 61080 and 61443 to the factory server
FORWARD += 61080=${SERVER_IP}:80 61443=${SERVER_IP}:443 # forward from DUT to server
endif
UNBLOCK += 22 # always unblock 22

FORWARD:=$(strip ${FORWARD})
UNBLOCK:=$(strip ${UNBLOCK})
DHCP_RANGE:=$(strip ${DHCP_RANGE})
VLAN:=$(strip ${VLAN})
endif

# Other repos to install, first word is the actual repo, the rest is the build command (if any)
REPOS += "https://github.com/glitchub/plio   git checkout -q py3 && make install"

# Files to be tweaked
FILES=/lib/systemd/system/pionic.service /boot/config.txt /etc/hosts

# function to invoke raspi-config in non-interactive mode, "on" enables, any other disables
raspi-config=raspi-config nonint $1 $(if $(filter on,$2),0,1)

# functions to invoke apt
APT-INSTALL=DEBIAN_FRONTEND=noninteractive apt install -y
APT-REMOVE=DEBIAN_FRONTEND=noninteractive apt remove --autoremove --purge -y

.PHONY: default clean packages repos files ${FILES}

ifdef INSTALL
default: files
ifdef SPI
	$(call raspi-config,do_spi,${SPI})
endif
ifdef I2C
	$(call raspi-config,do_i2c,${I2C})
endif
ifdef PRODUCTION
	systemctl disable rsyslog
endif
	systemctl enable pionic
ifdef LAN_IP
	# Install the NAT gateway
	[ -d rasping ] && git -C rasping pull || git clone https://github.com/glitchub/rasping
	make -C rasping UNBLOCK='${UNBLOCK}' LAN_IP=${LAN_IP} FORWARD='${FORWARD}' DHCP_RANGE='${DHCP_RANGE}' PINGABLE=yes LAN_VLAN='${VLAN}'
endif
	sync
	@echo "Reboot to start pionic"

# files depend on repos
files: ${FILES} legacy
${FILES}: repos

# Repos depend on packages. This logic is in bash because we must expand the quoted repo names
repos: packages
	@for r in ${REPOS}; do \
		read repo build < <(echo $$r); \
		dir=$${repo##*/}; \
		if [ -d $$dir ]; then \
			git -C $$dir pull || exit 1; \
		else \
			git clone $$repo || exit 1; \
		fi; \
		if [[ $$build ]]; then \
			( cd $$dir ; echo Running "$$build"; eval "$$build" ) || exit 1; \
		fi; \
	done

# install packages with apt
packages:; ${APT-INSTALL} $(sort ${PACKAGES})

else
# clean or uninstall, returns to target below
default: ${FILES} legacy
# disable SPI and I2C if we enabled it
ifdef SPI
	$(call raspi-config,do_spi,off)
endif
ifdef I2C
	$(call raspi-config,do_i2c,off)
endif
ifdef PRODUCTION
	# reinstate syslog
	systemctl enable --now rsyslog
endif
endif

# delete legacy stuff
.PHONY: legacy
legacy:
	sed -i '/pionic/d' /etc/rc.local
	rm -rf evdump runfor
	-${APT-REMOVE} omxplayer python3-pgmagick

# Add "pionic.server" hostname
/etc/hosts:
	sed -i '/pionic start/,/pionic end/d' $@
ifdef INSTALL
ifdef LAN_IP
	echo "# pionic start" >> $@
	echo "${LAN_IP} pionic.server" >> $@
	echo "# pionic end" >> $@
endif
endif

# pionic systemd service
/lib/systemd/system/pionic.service:
	rm -f $@
ifdef INSTALL
	echo '[Unit]' >> $@
	echo 'Description=Pi-based Network Instrument Controller' >> $@
	echo 'Wants=network-online.target' >> $@
	echo 'After=network-online.target' >> $@
	echo '[Service]' >> $@
	echo 'ExecStart=${CURDIR}/pionic.sh $(if ${SERVER_IP},,local)' >> $@
	echo '[Install]' >> $@
	echo 'WantedBy=multi-user.target' >> $@
endif

# configure kernel
/boot/config.txt:
	sed -i '/pionic start/,/pionic end/d' $@
ifdef INSTALL
ifdef HDMI_MODE
	echo "# pionic start" >> $@
	echo "[all]" >> $@
	echo "hdmi_force_hotplug=1" >> $@
	echo "hdmi_blanking=0" >> $@
	echo "hdmi_ignore_edid=0x5a000080" >> $@
	echo "hdmi_group=${HDMI_GROUP}" >> $@
	echo "hdmi_mode=${HDMI_MODE}" >> $@
	echo "# pionic end" >> $@
endif
endif

# Clean config files but don't remove packages or repos
clean:
	-systemctl stop pionic
	make INSTALL=
	sync
	@echo "Clean complete"

# Clean config files and remove packages and repos
uninstall:
	-systemctl stop pionic
	make INSTALL=
	@for r in ${REPOS}; do \
	    read repo build < <(echo $$r); \
	    dir=$${repo##*/} ; \
	    if [[ -d $$dir ]]; then \
	        [[ "$$build" ]] && make -C $$dir clean;
	        rm -rf $$dir; \
	    fi; \
	done
	if [ -d rasping ]; then make -C rasping uninstall && rm -rf rasping; fi
	${APT-REMOVE} $(sort ${PACKAGES})
	sync
	@echo "Uninstall complete"

endif
