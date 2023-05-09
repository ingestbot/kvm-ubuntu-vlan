#!/bin/sh

# This must exist in /etc/networkd-dispatcher/configured.d
# This must be executable 'chmod 755'

# https://gitlab.com/craftyguy/networkd-dispatcher

# https://askubuntu.com/questions/1032153/how-to-execute-post-up-scripts-with-netplan
# https://netplan.io/faq#use-pre-up%2C-post-up%2C-etc.-hook-scripts
# https://unix.stackexchange.com/questions/517995/prevent-netplan-from-creating-default-routes-to-0-0-0-0-0
# https://askubuntu.com/questions/1119164/how-to-permanently-disable-tso-gso-in-ubuntu-18-04

[ "$IFACE" != eno1 ] && exit 0

ethtool -K eno1 tcp-segmentation-offload off
