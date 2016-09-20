set -euo pipefail
#!/bin/bash

#The arguments passed to the to the command are:
#
#<proxy_address> <proxy_port> <server_address> <server_port>
#
#The <proxy_address> and <proxy_port> are derived from the first listener
#that is either IPv4, IPv6 or a UNIX socket. In the case of a UNIX socket
#listener the proxy_address will be the path of the socket and the
#<proxy_port> will be the string "NOT_USED". In a backend section, it's not
#possible to determine a listener, and both <proxy_address> and <proxy_port>
#will have the string value "NOT_USED".
#
#Some values are also provided through environment variables.
#
#Environment variables :
#  HAPROXY_PROXY_ADDR      The first bind address if available (or empty if not
#                          applicable, for example in a "backend" section).
#
#  HAPROXY_PROXY_ID        The backend id.
#
#  HAPROXY_PROXY_NAME      The backend name.
#
#  HAPROXY_PROXY_PORT      The first bind port if available (or empty if not
#                          applicable, for example in a "backend" section or
#                          for a UNIX socket).
#
#  HAPROXY_SERVER_ADDR     The server address.
#
#  HAPROXY_SERVER_CURCONN  The current number of connections on the server.
#
#  HAPROXY_SERVER_ID       The server id.
#
#  HAPROXY_SERVER_MAXCONN  The server max connections.
#
#  HAPROXY_SERVER_NAME     The server name.
#
#  HAPROXY_SERVER_PORT     The server port if available (or empty for a UNIX
#                          socket).
#
#  PATH                    The PATH environment variable used when executing
#                          the command may be set using "external-check path".
#
#If the command executed and exits with a zero status then the check is
#considered to have passed, otherwise the check is considered to have
#failed.

# Server_address are numerical
# Use this and HAPROXY_SERVER_NAME which is the dn non fqdn.
proxy_address=$1
proxy_port=$2
server_address=$3
server_port=$4

# Time variables for comparison
now=`/bin/date +%s`
# GNU
three_hours_ago=`/bin/date +%s -d "24 hours ago"` 
# BSD
#three_hours_ago=`/bin/date -v-24H +%s` 

# Fetch a timestamp and cache it for a certain amount of time.
function get_timestamp {
  file=/usr/local/etc/haproxy/timestamp-$1
  # Duration to cache the result, in seconds
  url=$3
  
  if [ -f $file ] 
  then
    modified=$(/usr/bin/stat -L --format %Y $file)
    if [ $((now-modified)) -lt $2 ]
    then
      /bin/cat $file
      return 0
    fi
  fi 
  
  set +e
  cmd="/usr/bin/curl -$5 -s -o $file -H host:$3 $4"
  echo -e "$now: running cmd $cmd\n" >> /tmp/log
  $cmd
  ret=$?
  echo -e "$now: ran cmd $cmd with ret $ret\n" >> /tmp/log
  set -e

  if [ $ret -eq 0 ]
  then
    cat $file
    return 0
  fi

  return -1
}

set +e

# Fetch the global timestamp
g_ts=$(get_timestamp global $((3600*60)) download.ceph.com http://$server_address:$server_port/timestamp 4)
ret=$?
if [ $ret -lt 0 ]
then
  g_ts=$ret
fi

# Fetch the backends timestamp
ip=4
if [ ${HAPROXY_SERVER_NAME: -1} == "6" ]
then
  ip=6
fi
ts=$(get_timestamp $HAPROXY_SERVER_NAME 60 ${HAPROXY_SERVER_NAME%%6*}.ceph.com http://$server_address:$server_port/timestamp $ip)
ret=$?
if [ $ret -lt 0 ]
then
  ts=$ret
fi

set -e

# Backend did not respond
if [ $ts -lt 0 ]
then
  exit 1
fi

# If the backend has a timestamp from three hours ago,
# It's ok.
if [ $ts -ge $three_hours_ago ]
then
  exit 0
fi

# The master was unreachable.
# Here's a tough one
# We can check that $ts is newer than three hours..
# Or we could just allow the server..
# TODO: go thrugh logic on this one
if [ $g_ts -lt 0 ]
then
  exit 1
fi

# Timestamp is less than global timestamp..
# Out of sync!
if [ $ts -lt $g_ts ] || [ $ts -lt $three_hours_ago ] 
then
  exit 1
fi

# Timestamp is greater than global timestamp..
# No, no! Are you from the future?
if [ $ts -gt $g_ts ]
then
  exit 1
fi

# All cases should be covered
exit 1
