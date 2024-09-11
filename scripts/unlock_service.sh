#!/bin/sh

DATESTR=`date`

logger -p user.warning "######################################################################"
logger -p user.warning "######################################################################"
logger -p user.warning "MY SERVICE IS RUNNING ON $DATESTR"
logger -p user.warning "######################################################################"
logger -p user.warning "######################################################################"

python3 /srv/scripts/unlock_daemon.py
