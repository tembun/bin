#!/bin/sh

#
# bat -- check out the battery charge in FreeBSD.
#

sysctl -n hw.acpi.battery.life
