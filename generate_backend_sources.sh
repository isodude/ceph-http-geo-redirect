#!/bin/bash

# Fetched from https://raw.githubusercontent.com/ceph/ceph/master/mirroring/mirror-ceph.sh
declare -a SOURCES
SOURCES=('de=de.ceph.com'
'se=se.ceph.com'
'cz=cz.ceph.com'
'au=au.ceph.com'
'hk=hk.ceph.com'
'fr=fr.ceph.com'
'uk=uk.ceph.com'
'us=us-east.ceph.com')

function dig_cname {
  cname=$(dig CNAME +short $1)
  if [ ! -z $cname ]
  then
    dig_cname $cname 
  fi
  dig +short $1
}

for source in ${SOURCES[@]}
do
  dns=$(dig A +short ${source##*=} | tail -n1)
  echo "${source%%=*}=$dns"
done

