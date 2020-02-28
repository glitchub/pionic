#!/bin/bash -eu

# This starts the test station operation. It is executed by systemd after the
# upstream network is up.

# Report errors before exit, this tries to look like the 'unbound variable' error
trap 'echo $0: line $LINENO: exit status $? >&2' ERR

# abort with a message
die() { echo "$0: $*" >&2; exit 1; }

((UID==0)) || die "Must be root"

# Where to put temp files, cgi/factory also needs to know this
tmp=/tmp/pionic

# create a tmp directory
rm -rf $tmp
mkdir -p $tmp

# script is in pionic top level directory
here=$(realpath ${0%/*})

if [[ ${2:-} == local ]]; then
    station=local
    echo "Test station is local"
    fixture=$here/fixtures/local/fixture.sh
else
    ip=$(ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' FS=' +|/')
    [[ $ip ]] || die "Requires an IP address on eth0"
    # get the last octet
    station=${ip##*.}
    echo "Test station ID is $station"
    # get fixture name from server
    echo "Requesting fixture name"
    curl="curl --connect-timeout 2 -qsSf"
    name=$($curl "http://localhost:61080/cgi-bin/factory?service=fixture") || die "No response from server"
    name=${name,,} # lowercase
    [[ $name && $name != none ]] || name=default
    fixture=$here/fixtures/$name/fixture.sh
    if ! [ -x $fixture ]; then
        # try to download it
        tarball="http://localhost:61080/downloads/fixtures/$name.tar.gz"
        echo "Fetching $tarball..."
        mkdir $tmp/fixture
        $curl $tarball | tar -C $tmp/fixture -xz || die "Fetch failed"
        fixture="$tmp/fixture/fixture.sh"
    fi
    [[ -x $fixture ]] || die "Fixture driver '$fixture' not found"
    echo "Fixture driver is '$fixture'"
fi

# Start beacon server if its installed
! [ -d $here/beacon ] || pgrep -f beacon &>/dev/null || $here/beacon/beacon send br0 &

# Run the fixture driver
echo "Starting '$fixture'"
$fixture $here $station

# It shouldn't return
kill $(jobs -p) &>/dev/null && wait $(jobs -p) || true;
die "'$fixture' exit status $?"
