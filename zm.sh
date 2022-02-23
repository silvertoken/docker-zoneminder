#!/bin/bash
### In zm.sh (make sure this file is chmod +x):

sleep 7s
exec /usr/bin/zmpkg.pl start >>/var/log/zm/zm.log 2>&1
