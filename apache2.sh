#!/bin/sh
### In apache2.sh (make sure this file is chmod +x):

#read pid cmd state ppid pgrp session tty_nr tpgid rest < /proc/self/stat
#trap "kill -TERM -$pgrp; exit" EXIT TERM KILL SIGKILL SIGTERM SIGQUIT

source /etc/apache2/envvars
exec apache2ctl -D FOREGROUND 2>&1 
