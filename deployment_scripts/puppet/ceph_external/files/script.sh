#!/bin/bash
awk  'BEGIN {RS="["}; {if ($1=="client.'$1']") print $4;}' /etc/ceph/keyring.bin|head -n1
