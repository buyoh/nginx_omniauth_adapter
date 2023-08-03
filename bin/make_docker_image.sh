#!/bin/bash

cd $(dirname $0)
cd ..

docker build . -f Dockerfile.custom -t nginx_omniauth_adapter
