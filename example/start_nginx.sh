#!/bin/sh

cd $(dirname $0)

docker run --rm -it \
  -v $PWD/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v $PWD/nginx-site.conf:/etc/nginx/nginx-site.conf:ro \
  --net host \
  nginx nginx
