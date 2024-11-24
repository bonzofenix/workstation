#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/common.sh

sudo -v
add_to_host '127.0.0.1 www.lanacion.com.ar'
add_to_host '127.0.0.1 www.twitter.com'
add_to_host '127.0.0.1 www.reddit.com'
add_to_host '127.0.0.1 www.instagram.com'
add_to_host '127.0.0.1 www.clarin.com'
add_to_host '127.0.0.1 www.x.com'

add_to_host 'dscacheutil -flushcache'
