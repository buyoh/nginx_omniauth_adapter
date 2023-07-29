#!/bin/bash

cd $(dirname $0)
cd ..

# TODO: configure env

docker run -it --rm \
  -p 8080:8080 \
  -e NGX_OMNIAUTH_SESSION_SECRET=neko \
  nginx_omniauth_adapter
