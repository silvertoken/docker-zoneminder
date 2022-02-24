#!/bin/bash
### In zm.sh (make sure this file is chmod +x):

sleep 5s
echo 'starting zm package scripts'
/usr/bin/zmpkg.pl start >>/var/log/zm/zm.log 2>&1 &
sleep 3s
echo 'starting apache'
/etc/service/apache2/run
