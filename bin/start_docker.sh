#!/bin/bash

cd $(dirname $0)
cd ..

# TODO: configure env

# [optional]
# Name of HTTP header to specify OmniAuth provider to be used (see below).
# Defaults to 'x-ngx-omniauth-provider`.
NGX_OMNIAUTH_PROVIDER_HTTP_HEADER=

# [must]
# Rack session secret. Should be set when not on dev mode
NGX_OMNIAUTH_SESSION_SECRET=neko

# [optinoal]
# URL of adapter. This is used for redirection. Should include protocol
# (e.g. `http://example.com`.)
# If this is not specified, adapter will perform redirect using given `Host`
# header.
NGX_OMNIAUTH_HOST=

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
# NOTE: ADAPTER と期限が違うのは何故？
NGX_OMNIAUTH_SESSION_COOKIE_TIMEOUT=

# NGX_OMNIAUTH_GITHUB_KEY
# NGX_OMNIAUTH_GITHUB_SECRET

# NGX_OMNIAUTH_GOOGLE_KEY
# NGX_OMNIAUTH_GOOGLE_SECRET
# NGX_OMNIAUTH_GOOGLE_HD

g_envs='
NGX_OMNIAUTH_PROVIDER_HTTP_HEADER
NGX_OMNIAUTH_SESSION_SECRET
NGX_OMNIAUTH_HOST
NGX_OMNIAUTH_ALLOWED_APP_CALLBACK_URL
NGX_OMNIAUTH_ALLOWED_BACK_TO_URL
NGX_OMNIAUTH_ADAPTER_REFRESH_INTERVAL
NGX_OMNIAUTH_SESSION_COOKIE_NAME
NGX_OMNIAUTH_SESSION_COOKIE_TIMEOUT
'

g_envargs=
for varname in $g_envs; do
  if [[ ! -z $varname]]; then
    g_envargs="$g_envargs $varname=${!varname}"
  fi
done

docker run -it --rm \
  -p 18081:8080 \
  -e NGX_OMNIAUTH_DEV=1 \
  -e RACK_ENV=development \
  $g_envargs \
  nginx_omniauth_adapter
