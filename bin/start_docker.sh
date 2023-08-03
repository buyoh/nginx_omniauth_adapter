#!/bin/bash

ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH=
if [[ -f $1 ]]; then
  ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH=$(realpath $1)
fi

cd $(dirname $0)
cd ..

# [optional]
# Name of HTTP header to specify OmniAuth provider to be used (see below).
# Defaults to 'x-ngx-omniauth-provider`.
NGX_OMNIAUTH_PROVIDER_HTTP_HEADER=

# [must]
# Rack session secret. Should be set when not on dev mode
NGX_OMNIAUTH_SESSION_SECRET=$(openssl rand -hex 32)

# [optinoal]
# URL of adapter. This is used for redirection. Should include protocol
# (e.g. `http://example.com`.)
# If this is not specified, adapter will perform redirect using given `Host`
# header.
NGX_OMNIAUTH_HOST=https://tesuto.ukibune.net

# [optional]
# (regexp): If specified, URL only matches to this are allowed for app callback url.
NGX_OMNIAUTH_ALLOWED_APP_CALLBACK_URL=

# [optional]
# (regexp): If specified, URL only matches to this are allowed for back_to url.
NGX_OMNIAUTH_ALLOWED_BACK_TO_URL=

# [optional]
# (integer): Interval to require refresh session cookie on app domain
# (in second, default 1 day).
NGX_OMNIAUTH_ADAPTER_REFRESH_INTERVAL=

# [optional]
# session cookie name (default `ngx_omniauth`)
NGX_OMNIAUTH_SESSION_COOKIE_NAME=

# [optional]
# session cookie expiry (default 3 days)
NGX_OMNIAUTH_SESSION_COOKIE_TIMEOUT=

# [optional][appended]
# use https only cookie if true
NGX_A_OMNIAUTH_SESSION_SECURE=true

NGX_OMNIAUTH_GITHUB_KEY=
NGX_OMNIAUTH_GITHUB_SECRET=

NGX_OMNIAUTH_GOOGLE_KEY=
NGX_OMNIAUTH_GOOGLE_SECRET=
NGX_OMNIAUTH_GOOGLE_HD=
if [[ -n $ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH ]]; then
  echo 'google oauth is enabled'
  # NGX_OMNIAUTH_HOST=$(cat $ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH | jq '.web.auth_uri' -r)
  NGX_OMNIAUTH_GOOGLE_KEY=$(cat $ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH | jq '.web.client_id' -r)
  NGX_OMNIAUTH_GOOGLE_SECRET=$(cat $ARG_GOOGLE_CLOUD_CLIENT_SECRET_FILEPATH | jq '.web.client_secret' -r)
fi


g_envs='
NGX_OMNIAUTH_PROVIDER_HTTP_HEADER
NGX_OMNIAUTH_SESSION_SECRET
NGX_OMNIAUTH_HOST
NGX_OMNIAUTH_ALLOWED_APP_CALLBACK_URL
NGX_OMNIAUTH_ALLOWED_BACK_TO_URL
NGX_OMNIAUTH_ADAPTER_REFRESH_INTERVAL
NGX_OMNIAUTH_SESSION_COOKIE_NAME
NGX_OMNIAUTH_SESSION_COOKIE_TIMEOUT
NGX_A_OMNIAUTH_SESSION_SECURE
NGX_OMNIAUTH_GITHUB_KEY
NGX_OMNIAUTH_GITHUB_SECRET
NGX_OMNIAUTH_GOOGLE_KEY
NGX_OMNIAUTH_GOOGLE_SECRET
NGX_OMNIAUTH_GOOGLE_HD
'

g_envargs=
for varname in $g_envs; do
  if [[ ! -z $varname ]] && [[ ! -z ${!varname} ]]; then
    g_envargs="$g_envargs -e $varname=${!varname}"
  fi
done

# メールアドレス等を任意に指定できる develop 版認証が追加される。
g_envdevevelop=
# g_envdevevelop="-e RACK_ENV=development"

docker run -it --rm \
  -p 18081:8080 \
  -v $PWD/lib:/app/lib \
  -v $PWD/config.ru:/app/config.ru \
  $g_envargs $g_envdevevelop \
  nginx_omniauth_adapter
