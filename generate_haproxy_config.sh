#!/bin/bash
# Author: Josef Johansson <josef86@gmail.com>
# This file is a really quick-and-dirty way of generating haproxy
# configuration from a list of backends

function generate {
 echo "global
  maxconn 4096
  external-check
defaults
  balance roundrobin
  log global
  mode http
  timeout connect 5000
  timeout client 50000
  timeout server 50000
  option external-check
  external-check command /usr/local/etc/haproxy/check-timestamp.sh

frontend port_1389
  bind *:1389
  default_backend stats_auth

backend stats_auth
    stats enable

frontend port_80
  bind *:80
  
  http-request set-header backend %[src,map_ip(/usr/local/etc/haproxy/geoip.lst)]
"
 for country in ${countries[@]}
 do
  echo " acl ${country%%=*} req.fhdr(backend) -m str ${country%%=*}"
 done
 for country in ${countries[@]}
 do
  echo " use_backend ${country%%=*} if ${country%%=*}"
 done

 echo " default_backend default

##
# Backends
##
 backend default
  server download 127.0.1.1:80 redir http://download.ceph.com/ weight 1

"

 for country in ${countries[@]}
 do
  echo "backend ${country%%=*}"
  echo " server download 173.236.253.173:80 redir http://download.ceph.com/ weight 1"
  for country_other in ${countries[@]}
  do
    weight=2
    if [ ${country_other%%=*} == ${country%%=*} ]
    then
      weight=256
    fi
    echo " server ${country_other%%=*} ${country_other##*=}:80 redir http://${country_other%%=*}.ceph.com check weight ${weight}"
  done
 done
}

declare -a countries=($(./generate_backend_sources.sh))
generate > haproxy.cfg
