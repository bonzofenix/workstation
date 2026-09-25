#!/usr/bin/env bash

export SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "$SCRIPT_DIR/common.sh"

# Hosts to block: one per line (# comments allowed). A personal list in the
# private memory repo wins; otherwise block only the default below.
hosts_file="${MEMORY_DIR:-$HOME/workspace/memory}/blocked-hosts.txt"
if [ -f "$hosts_file" ]; then
  hosts="$(sed -e 's/\r$//' -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$hosts_file")"
else
  hosts=$'www.twitter.com\nwww.x.com\nx.com'
fi

sudo -v
while IFS= read -r host; do
  add_to_host "127.0.0.1 $host"
done <<< "$hosts"
# Flush the DNS cache so the blocks apply now. (This used to be passed to
# add_to_host, which wrote it into /etc/hosts as a line instead of running it.)
sudo dscacheutil -flushcache
