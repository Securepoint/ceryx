#!/bin/bash

pushd /usr/src

sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" curl build-essential git devscripts libssl-dev dh-systemd
