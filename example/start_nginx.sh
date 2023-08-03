#!/bin/bash

cd $(dirname $0)

ARG_SERVER_NAME=$1

if [[ x$ARG_SERVER_NAME == x ]]; then
  echo "usage: $0 servername"
  exit 1
fi

rm -rf var
mkdir var
echo $ARG_SERVER_NAME | ruby replacer.rb

if [[ ! -f var/nginx.conf ]] || [[ ! -f var/nginx-site.conf ]]; then
  echo "replacer.rb failed"
  exit 1
fi

docker run --rm -it \
  -v $PWD/var/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v $PWD/var/nginx-site.conf:/etc/nginx/nginx-site.conf:ro \
  --net host \
  nginx nginx
