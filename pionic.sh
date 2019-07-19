#!/bin/bash -eu

# This runs at boot, start test station operation,

# It can also be run manually to restart all services, in that case uses the
# cached server IP and fixture.

# report errors before exit, this tries to look like the 'unbound variable' error
trap 'echo $0: line $LINENO: exit status $? >&2' ERR

# abort with a message
die() { echo "$0: $*" >&2; exit 1; }

grep -q Raspberry /etc/rpi-issue &>/dev/null || die "Requires a Raspberry Pi"
((UID==0)) || die "Must be run as root"

here=$(realpath ${0%/*})

# return ip address for interface $1 and true, or false if no IP
ipaddr() { local s=$(ip -4 -o a show dev $1 2>/dev/null | awk '{print $4}'); [[ $s ]] && echo $s; }

# Where to put temp files, cgi/factory also needs to know this
tmp=/tmp/pionic

# curl -q=disable curl.config, -s=silent (no status), -S=show error, -f=fail with exit status 22 
curl="curl -qsSf"

# turn console on and off
console()
{
    case "$1" in
        off) 
            setterm --cursor off > /dev/tty1
            echo 0 > /sys/class/vtconsole/vtcon1/bind
            dmesg -n 1
            ;;
        *)  
            echo 1 > /sys/class/vtconsole/vtcon1/bind
            setterm --cursor on > /dev/tty1
            ;;
    esac
    true
}    

case "${1:-}" in
    start)
        mkdir -p $tmp
        echo $$ > $tmp/.pid
        shift
        # maybe use cached params
        (($#)) || set -- $(cat $tmp/.cached 2>/dev/null)
        # SERVER_IP is required
        SERVER_IP=${1:-}
        [[ "$SERVER_IP." =~ ^(([1-9][0-9]?|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){4}$ ]] || die "Must specify a valid factory server IP address"
        # fixture is optional
        FIXTURE=${2:-}
        # remember params in case of restart, also for cgi/factory
        echo $* > $tmp/.cached
        
        # after this point, kill shell children on exit and reinstate console 
        trap 'exs=$?; 
            kill $(jobs -p) &>/dev/null || true; 
            console on || true;  
            exit $exs' EXIT

        # wait for ethernet and usb dongle
        while true; do
            wait=0
            if ! station_ip=$(ipaddr eth0); then
                if ! (($(cat /sys/class/net/eth0/carrier))); then
                    echo "Ethernet is unplugged"
                 else
                    echo "Waiting for DHCP on MAC $(cat /sys/class/net/eth0/address)"
                fi
                wait=1
            else
                station=${station_ip##*.}
                station=${station%/*}
            fi

            if ! lan_ip=$(ipaddr eth1); then
                if ! [ -d /sys/class/net/eth1 ]; then
                    echo "USB ethernet is not attached"
                else
                    # dhcpcd should bring it up soon
                    echo "Waiting for IP on USB ethernet"
                fi    
                wait=1
            else            
                if ! pgrep -f cgiserver &>/dev/null; then 
                    echo "Starting cgi server"
                    $here/cgiserver -p 80 -d ~pi/pionic/cgi &
                    wait=1
                fi
                if [ -d $here/beacon ] && ! pgrep -f beacon; then
                    # advertise the server ip
                    echo "Starting beacon server"
                    $here/beacon/beacon send eth1 $SERVER_IP &
                    wait=1
                fi  
            fi    

            ((wait)) || break

            sleep 1
        done

        # now try to fetch the fixture driver
        if ! [[ $FIXTURE ]]; then
            echo "Requesting fixture from $SERVER_IP"
            FIXTURE=$($curl "http://$SERVER_IP/cgi-bin/factory?service=fixture") || die "Fixture request failed"
        fi    

        echo "Using fixture '$FIXTURE'"

        rm -rf $tmp/fixtures
        mkdir $tmp/fixtures

        if  [[ $FIXTURE != none ]]; then
            
            tarball="http://$SERVER_IP/fixture.tar.gz"
            echo "Fetching $tarball..."
            $curl $tarball | tar -C $tmp/fixtures -xz || die "Failed to fetch fixture tarball"

            [[ -e $tmp/fixtures/$FIXTURE ]] || die "No driver for fixture '$FIXTURE'"

        else
            # just create a bogus 'none' driver
            cat <<EOT > $tmp/fixtures/none
printf "TEST STATION $station READY" | $here/cgi/display text fg=white bg=blue align=center point=40
while true; do sleep 1d; done
EOT
        fi 

        # source the fixture driver, it should loop forever
        console off
        source $tmp/fixtures/$FIXTURE

        # but die if it doesn't
        die "Fixture driver '$FIXTURE' returned"
        ;;

    stop)
        { 
            kill $(cat $tmp/.pid) || cat /dev/zero > /dev/fb0 || true 
            rm -f $tmp/.pid; 
        } &>/dev/null    
        ;;

    res*)
        $0 stop
        $0 start
        ;;

    *)  die "Usage: $0 stop | start [server_ip [fixture]] | restart"
        ;;
esac
true

