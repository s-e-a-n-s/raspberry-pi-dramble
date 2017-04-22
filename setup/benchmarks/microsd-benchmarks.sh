#!/bin/bash

# Raspberry Pi microSD card benchmark script.
#
# A script I use to automate the running and reporting of benchmarks I compile
# for: http://www.pidramble.com/wiki/benchmarks/microsd-cards
#
# Usage:
#   # Run it locally.
#   $ sudo ./microsd-benchmarks.sh [iozonesize=100M]
#
#   # Run it straight from GitHub.
#   $ curl https://raw.githubusercontent.com/geerlingguy/raspberry-pi-dramble/master/setup/benchmarks/microsd-benchmarks.sh | sudo bash
#
# Another good benchmark:
#   $ curl http://www.nmacleod.com/public/sdbench.sh | sudo bash
#
# Author: Jeff Geerling, 2016

printf "\n"
printf "Raspberry Pi Dramble microSD benchmarks\n"

CLOCK="$(grep "actual clock" /sys/kernel/debug/mmc0/ios 2>/dev/null | awk '{printf("%0.3f MHz", $3/1000000)}')"
if [ -n "$CLOCK" ]; then
  echo "microSD clock: $CLOCK"
fi
printf "\n"

# Variables.
IOZONE_VERSION=iozone3_434
IOZONE_SIZE_DEFAULT="100M"

# Command Line args
IOZONE_SIZE=$1
if [ -z "$IOZONE_SIZE" ]; then IOZONE_SIZE=$IOZONE_SIZE_DEFAULT; fi
if ! [[ "$IOZONE_SIZE" =~ ^[0-9]+[kKmMgG]?$ ]]; then
  printf "!!! Invalid iozone size '$IOZONE_SIZE' (arg1).  Expecting #,#k,#m,#g (eg, '1024' or '100m' or '1g')\n\n"
  exit 1;
fi

#
# Install dependencies.
#

# Check hdparam
if [ ! `which hdparm` ]; then
  printf "Installing hdparm...\n"
  apt-get install -y hdparm
  printf "Install complete!\n\n"
fi

# Check iozone - build and reference locally if absent.
if [ `which iozone` ]; then
  IOZONE="iozone"
else
  printf "Fetching/building iozone...\n"
 
  # iozone dependencies
  if [ ! `which curl` ]; then
    printf "Installing curl...\n"
    apt-get install -y curl
    printf "Install complete!\n\n"
  fi
  if [ ! `which make` ]; then
    printf "Installing build tools...\n"
    apt-get install -y build-essential
    printf "Install complete!\n\n"
  fi

  # Determine location for iozone build... homedir.
  MYUSER="$SUDO_USER";
  if [ -z "$MYUSER" ]; then MYUSER="$USER"; fi
  if [ -z "$MYUSER" ]; then printf "!!! Unable to determine user... exiting.\n\n"; exit 1; fi

  IOZONE_INSTALL_PATH=$(getent passwd $MYUSER | cut -d: -f6)
  cd $IOZONE_INSTALL_PATH

  # Download and build iozone.
  IOZONE="$IOZONE_INSTALL_PATH/$IOZONE_VERSION/src/current/iozone"
  if [ ! -f "$IOZONE" ]; then
    printf "Installing iozone (user:'$MYUSER' loc:'$IOZONE_INSTALL_PATH')...\n"
    curl "http://www.iozone.org/src/current/$IOZONE_VERSION.tar" | tar -x
    cd $IOZONE_VERSION/src/current
    make --quiet linux-arm
    printf "Iozone install complete!\n\n"
  fi
fi # end of 'which iozone' check;

# dd out directory (attempt to be OSX friendly)
DD_OUT=`mktemp 2>/dev/null || mktemp -t 'microsd-benmark'`

#
# Run benchmarks.
#

printf "Running hdparm test...\n"
hdparm -t /dev/mmcblk0
printf "\n"

printf "Running dd test (of:'${DD_OUT}')...\n"
dd if=/dev/zero of=${DD_OUT} bs=8k count=50k conv=fsync;
rm -f ${DD_OUT}
printf "\n"

printf "Running iozone test (size:'${IOZONE_SIZE}')...\n"
$IOZONE -e -I -a -s ${IOZONE_SIZE} -r 4k -i 0 -i 1 -i 2
printf "\n"

printf "microSD card benchmark complete!\n\n"

