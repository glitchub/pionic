#!/bin/bash -eu

# This starts the test station operation. It runs in background at boot.

# Report errors before exit, this tries to look like the 'unbound variable' error
trap 'echo $0: line $LINENO: exit status $? >&2' ERR

# abort with a message
die() { echo "$0: $*" >&2; exit 1; }

grep -q Raspberry /etc/rpi-issue &>/dev/null || die "Requires a Raspberry Pi"
((UID==0)) || die "Must be run as root"

here=$(realpath ${0%/*})

# Return ip address for interface $1 and true, or false if no IP
ipaddr() { local s=$(ip -4 -o a show dev $1 2>/dev/null | awk '{print $4}'); [[ $s ]] && echo $s; }

# Where to put temp files, cgi/factory also needs to know this
tmp=/tmp/pionic

# curl timeout after 4 seconds, -q=disable curl.config, -s=silent (no status), -S=show error, -f=fail with exit status 22
curl="curl --connect-timeout 2 -qsSf"

case "${1:-}" in
    start)
        (
            # create a tmp directory
            rm -rf $tmp
            mkdir -p $tmp

            # store subshell pid for 'stop'
            echo $BASHPID > $tmp/pid

            station=""
            [[ ${2:-} == local ]] && station=local

            # after this point, kill shell children on exit
            trap 'exs=$?;
                echo 1 > /sys/class/vtconsole/vtcon1/bind;
                chvt 1 < /dev/console;
                kill $(jobs -p) &>/dev/null && wait $(jobs -p) || true;
                exit $exs' EXIT

            if [[ $station != local ]]; then
                # require eth0 for normal operation
                while ((! $(cat /sys/class/net/eth0/carrier))); do
                    echo "Ethernet is not attached"
                    sleep 1
                done

                while ! station_ip=$(ipaddr eth0); do
                    echo "Waiting for station ID (MAC=$(cat /sys/class/net/eth0/address))"
                    sleep 1
                done

                station=${station_ip##*.}
                station=${station%/*}
            fi

            while ! ipaddr br0 &>/dev/null; do
                echo "Waiting for br0 to come up"
                sleep 1
            done

            while ! [[ $(bridge link show 2>/dev/null) ]]; do
                echo "Waiting for bridged device (is USB ethernet attached?)"
                sleep 1
            done

            # start beacon if enabled
            ! [ -d $here/beacon ] || pgrep -f beacon &>/dev/null || $here/beacon/beacon send br0 &


            if [[ $station == local ]]; then
                # use local fixture driver
                fixture=$here/fixtures/local/fixture.sh
            else
                # get fixture name from server
                echo "Requesting fixture name"
                name=$($curl "http://localhost:61080/cgi-bin/factory?service=fixture") || die "No response from server"
                name=${name,,} # lowercase
                [[ $name && $name != none ]] || name=default
                fixture=$here/fixtures/$name/fixture.sh
                if ! [ -x $fixture ]; then
                    # try to download it
                    fixtures="http://localhost:61080/fixtures.tar.gz"
                    echo "Fetching $fixtures..."
                    mkdir $tmp/fixtures
                    $curl $fixtures | tar -C $tmp/fixtures -xz || die "Fetch failed"
                    fixture="tmp/fixtures/$name/fixture.sh"
                fi
            fi

            [[ -x $fixture ]] || die "Fixture driver '$fixture' not found"
            echo "Starting '$fixture'"
            $fixture $here $station
            # in theory, it doesn't return
            die "'$fixture' exit status $?"
        ) &
        ;;

    stop)
        if [ -e $tmp/pid ]; then
            kill $(cat $tmp/pid) &>/dev/null || true
            rm -f $tmp
        fi
        ;;

    *)  die "Usage: $0 stop | start [ local ]"
        ;;
esac
true
