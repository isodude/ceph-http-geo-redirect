#!/bin/sh
set -euo pipefail

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
now=`date +%s`
three_hours_ago=`date -v-3H +%s` 

# Fetch a timestamp and cache it for a certain amount of time.
function get_timestamp {
  file=timestamp-$1
  # Duration to cache the result, in seconds
  url=$3
  
  if [ -f $file ] 
  then
    modified=$(stat -L -f %m $file)
    if [ $((now-modified)) -lt $2 ]
    then
      cat $file
      return 0
    fi
  fi 
  
  set +e
  /usr/bin/curl -s -o $file $3
  ret=$?
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
g_ts=$(get_timestamp global $((3600*60)) http://download.ceph.com/timestamp)
ret=$?
if [ $ret -lt 0 ]
then
  g_ts=$ret
fi

# Fetch the backends timestamp
ts=$(get_timestamp $HAPROXY_SERVER_NAME 10 http://$HAPROXY_SERVER_NAME.ceph.com/timestamp)
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
