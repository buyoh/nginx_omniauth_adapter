#!/bin/bash

function json5json() {
  ruby -e 'require "json5";require "json";puts JSON.generate(JSON5.parse(STDIN.read))'
}

ARG_CONFIG_JSON_FILEPATH=
if [[ -f $1 ]]; then
  ARG_CONFIG_JSON_FILEPATH=$(realpath $1)
else
  echo "usage: $0 config_json [google_json]"
  exit 1
fi

ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH=
if [[ -f $2 ]]; then
  ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH=$(realpath $2)
fi

cd $(dirname $0)
cd ..

g_port=18081
if [[ x$PORT != x ]]; then
  g_port=$PORT
fi

NGX_OMNIAUTH_SESSION_SECRET=$(openssl rand -hex 32)

NGX_A_OMNIAUTH_CONFIG_JSON=$(cat $ARG_CONFIG_JSON_FILEPATH | json5json)

if [[ -f $ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH ]]; then
  NGX_A_OMNIAUTH_GOOGLE_CLIENT_SECRET_JSON=$(cat $ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH | json5json)
fi

g_envs='
NGX_OMNIAUTH_SESSION_SECRET
NGX_A_OMNIAUTH_CONFIG_JSON
NGX_A_OMNIAUTH_GOOGLE_CLIENT_SECRET_JSON
'

g_envargs=
for varname in $g_envs; do
  if [[ ! -z $varname ]] && [[ ! -z ${!varname} ]]; then
    g_envargs="$g_envargs -e $varname=${!varname}"
  fi
done

docker run --rm \
  -p $g_port:8080 \
  -v $PWD/lib:/app/lib \
  -v $PWD/config.custom.ru:/app/config.ru \
  $g_envargs \
  nginx_omniauth_adapter
