#!/bin/bash


function dig_cname {
  cname=$(dig CNAME +short $1)
  if [ ! -z $cname ]
  then
    dig_cname $cname 
  fi
  dig +short $1
}

# Fetched from https://raw.githubusercontent.com/ceph/ceph/master/mirroring/MIRRORS
mirrors=($(curl -s https://raw.githubusercontent.com/ceph/ceph/master/mirroring/MIRRORS | cut -d ':' -f 1))
for mirror in ${mirrors[@]}
do
  country=${mirror%%\.*}
  case $country in
    download) continue;;
    us-east) country=us;;
    eu) continue;;
  esac
  dns=$(dig A +short $mirror | tail -n1)
  dns6=$(dig AAAA +short $mirror | tail -n1)
  echo "$country=$dns=$dns6"
done

