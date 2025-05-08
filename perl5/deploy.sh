#!/bin/env bash

rsync -av --relative TrueNAS PVE/Storage/LunCmd/TrueNAS.pm /usr/share/perl5/

service pve-cluster restart && service pvedaemon restart && service pvestatd restart && service pveproxy restart 