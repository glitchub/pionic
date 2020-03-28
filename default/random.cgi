#!/bin/bash

# Print random bytes from /dev/urandom, in hex.
# Number of bytes can be specified on the command line, default is 32
bytes=${1:-32}
hexdump -n $bytes -e $bytes'/1 "%02X" "\n"' /dev/urandom
