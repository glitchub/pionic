#!/bin/bash -eu

# This starts the test station. It is executed by systemd after the upstream
# network is up. It looks for default or downloadable test fixture driver and
# runs fixture.sh.

# Report errors before exit, this tries to look like the 'unbound variable' error
trap 'echo $0: line $LINENO: exit status $? >&2' ERR

# abort with a message
die() { echo "$0: $*" >&2; exit 1; }

((UID==0)) || die "Must be root"

# create a tmp directory
tmp=/tmp/pionic
rm -rf $tmp
mkdir -p $tmp

# script is in pionic top level directory
here=$(realpath ${0%/*})

ipaddr() { ip -4 -o addr show $1 2>/dev/null | awk '{print $4; got=1} END{exit !got}' FS=' +|/'; }

if [[ ${1:-} == local ]]; then
    station=local
    fixture=$here/default/fixture.sh
else
    tries=0
    until ip=$(ipaddr eth0); do
        ((tries++)) || echo "Waiting for an IP address on eth0"
        sleep 1
    done

    # get the last octet
    station=${ip##*.}
    echo "Requesting fixture for station ID $station"
    # get fixture name from server
    curl="curl --connect-timeout 2 -qsSf"
    name=$($curl "http://localhost:61080/cgi-bin/factory?service=fixture") || die "Request failed"
    name=${name,,} # lowercase
    if [[ -z $name || $name == none ]]; then
        name=default
        fixture=$here/default/fixture.sh
    else
        # try to download it
        tarball="http://localhost:61080/downloads/fixtures/$name.tar.gz"
        echo "Fetching $tarball..."
        mkdir $tmp/fixture
        $curl $tarball | tar -C $tmp/fixture -xz || die "Fetch failed"
        fixture="$tmp/fixture/fixture.sh"
    fi
fi
echo "Fixture driver is '$fixture'"
[[ -x $fixture ]] || die "Fixture driver not found"

# Start beacon server if it's installed
if [ -d $here/beacon ] && ! pgrep -f beacon &>/dev/null; then
    echo "Starting beacon"
    $here/beacon/beacon send br0 &
fi

# try to clean up on exit
trap 'x=$?; echo $0 exit $x; set +eu; kill $(jobs -p) &>/dev/null && wait $(jobs -p);' EXIT

# Run the fixture driver
$fixture $here $station

# It shouldn't return
die "'$fixture' exit status $?"
