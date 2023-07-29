#!/bin/bash

cd $(dirname $0)
cd ..

docker build . -t nginx_omniauth_adapter
