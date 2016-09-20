#!/bin/bash
# Author: Josef Johansson <josef86@gmail.com>
# This file is a really quick-and-dirty way of generating haproxy
# configuration from a list of backends

function dn {
  echo $1 | cut -d '=' -f 1
}

function ipv4 {
  echo $1 | cut -d '=' -f 2
}

function ipv6 {
  echo $1 | cut -d '=' -f 3
}

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

listen stats
  bind :1936
  mode http
  stats enable
  stats hide-version
  stats uri /
  stats realm Haproxy\ Statistics
  stats auth stats:ceph-mirrors-rocks

frontend port_80
  bind *:80
  
  http-request set-header backend %[src,map_ip(/usr/local/etc/haproxy/geoip.lst)]
"
 for country in ${countries[@]}
 do
  echo " acl $(dn $country) req.fhdr(backend) -m str $(dn $country)"
 done
 for country in ${countries[@]}
 do
  echo " use_backend $(dn $country) if $(dn $country)"
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
  echo "backend $(dn $country)"
  echo " server download 173.236.253.173:80 redir http://download.ceph.com/ weight 1"
  echo " server download6 2607:f298:6050:51f3:f816:3eff:fe71:9135:80 redir http://download.ceph.com/ weight 1"
  for _country in ${countries[@]}
  do
    weight=2
    if [ $(dn $_country) == $(dn $country) ]
    then
      weight=256
    fi
    echo " server $(dn $_country) $(ipv4 $_country):80 redir http://$(dn $_country).ceph.com check weight ${weight}"
    echo " server $(dn $_country)6 $(ipv6 $_country):80 redir http://$(dn $_country).ceph.com check weight ${weight}"
  done
 done
}

declare -a countries=($(./generate_backend_sources.sh))
generate > haproxy.cfg
