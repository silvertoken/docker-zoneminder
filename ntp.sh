#!/bin/bash
### In zm.sh (make sure this file is chmod +x):

exec /usr/sbin/ntpd -n 2>&1
