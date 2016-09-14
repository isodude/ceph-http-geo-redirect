#!/bin/bash

if docker-compose -p haproxy-configtest -f docker-compose-configtest.yml run --rm haproxy-configtest; then
  echo 'OK!'
  exit 0
else
  echo 'ERROR!'
  exit 1
fi
