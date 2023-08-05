require_relative 'lib/nginx_omniauth_adapter'
require 'omniauth'
require 'omniauth/version'
require 'open-uri'
require 'json'

def is_true_value(val)
  !!val && val != 0 && val != '0' && val != ''
end

json_config = ENV['NGX_A_OMNIAUTH_CONFIG_JSON']
if !json_config || json_config.empty?
  warn 'NGX_A_OMNIAUTH_CONFIG_JSON is empty'
  exit 1
end

# Raise exceptions
json_config = JSON.parse(json_config)

google_secet_json_config = ENV['NGX_A_OMNIAUTH_GOOGLE_CLIENT_SECRET_JSON']
if google_secet_json_config && !google_secet_json_config.empty?
  google_secet_json_config = JSON.parse(google_secet_json_config)
else
  google_secet_json_config = nil
end

# -----------------------------------------------------------------------------

# Same as NGX_OMNIAUTH_DEV
# Set 1 or true to enable dev mode
arg_dev = is_true_value(json_config['dev'])
# Same as RACK_ENV, and set 
arg_rack_env = nil
arg_rack_env = ENV['RACK_ENV'] if ENV['RACK_ENV'] && !ENV['RACK_ENV'].empty?
arg_rack_env = json_config['rack_env'] if json_config['rack_env']
ENV['RACK_ENV'] = arg_rack_env

# [optional] NGX_OMNIAUTH_SECRET
# The secret to encrypt
# Defaults to OpenSSL::Cipher.new(SESSION_PASS_CIPHER_ALGORITHM)
arg_secret = nil

# [must] NGX_OMNIAUTH_SESSION_SECRET
# Set secret via ENV.
# Rack session secret. Should be set when not on dev mode
arg_session_secret = ENV['NGX_OMNIAUTH_SESSION_SECRET']

# [optional] NGX_OMNIAUTH_PROVIDER_HTTP_HEADER
# Name of HTTP header to specify OmniAuth provider to be used (see below).
# Defaults to 'x-ngx-omniauth-provider`.
arg_provider_http_header = json_config['provider_http_header'] || 'x-ngx-omniauth-provider'
abort "arg_provider_http_header is not String" unless arg_provider_http_header.is_a? String

# [optinoal] NGX_OMNIAUTH_HOST
# URL of adapter. This is used for redirection. Should include protocol
# (e.g. `http://example.com`.)
# If this is not specified, adapter will perform redirect using given `Host`
# header.
arg_host = json_config['host']

# [optional] NGX_OMNIAUTH_ALLOWED_APP_CALLBACK_URL
# (regexp): If specified, URL only matches to this are allowed for app callback url.
arg_allowed_app_callback_url = json_config['allowed_app_callback_url_regexp']
arg_allowed_app_callback_url = arg_allowed_app_callback_url ? Regexp.new(arg_allowed_app_callback_url) : nil

# [optional] NGX_OMNIAUTH_ALLOWED_BACK_TO_URL
# (regexp): If specified, URL only matches to this are allowed for back_to url.
arg_allowed_back_to_url = json_config['allowed_back_to_url']
arg_allowed_back_to_url = arg_allowed_back_to_url ? Regexp.new(arg_allowed_back_to_url) : nil

# [optional] NGX_OMNIAUTH_APP_REFRESH_INTERVAL
arg_app_refresh_interval = json_config['app_refresh_interval']

# [optional] NGX_OMNIAUTH_ADAPTER_REFRESH_INTERVAL
# (integer): Interval to require refresh session cookie on app domain
# (in second, default 1 day).
arg_adapter_refresh_interval = json_config['adapter_refresh_interval'] || (60 * 60 * 24)

# [optional] NGX_OMNIAUTH_SESSION_COOKIE_NAME
# session cookie name (default `ngx_omniauth`)
arg_session_cookie_name = json_config['session_cookie_name'] || 'ngx_omniauth'
abort "session_cookie_name is not String" unless arg_session_cookie_name.is_a? String

# [optional] NGX_OMNIAUTH_SESSION_COOKIE_TIMEOUT
# session cookie expiry (default 3 days)
arg_session_cookie_timeout = json_config['session_cookie_timeout'] || (60 * 60 * 24 * 3)
abort "session_cookie_timeout is not Numeric" unless arg_session_cookie_timeout.is_a? Numeric

# [optional][appended] NGX_A_OMNIAUTH_SESSION_SECURE
# use https only cookie if true
arg_session_secure = is_true_value(json_config['session_secure']) 

# NGX_OMNIAUTH_GOOGLE_KEY
# NGX_OMNIAUTH_GOOGLE_SECRET
arg_google_key = nil
arg_google_secret = nil
if google_secet_json_config
  arg_google_key = google_secet_json_config['web']['client_id']
  arg_google_secret = google_secet_json_config['web']['client_secret']
end
# TODO: impl
arg_google_hd = ENV['NGX_OMNIAUTH_GOOGLE_HD']
gh_teams = ENV['NGX_OMNIAUTH_GITHUB_TEAMS'] && ENV['NGX_OMNIAUTH_GITHUB_TEAMS'].split(/[, ]/)

# Policy
policy_allow_list = nil
if policy = json_config['policy']
  if al = policy['allow_list']
    # validate
    if al.values.all? {|allow| (!allow['user'] || allow['user'].is_a?(Array))}
      policy_allow_list = al
    end
  end
end

# -----------------------------------------------------------------------------

policy_proc = proc {
  # TODO: サーバの再起動なしで再設定できるようにする。
  if gh_teams && current_user[:provider] == 'github'
    unless (current_user_data[:gh_teams] || []).any? { |team| gh_teams.include?(team) }
      next false
    end
  end

  if policy_allow_list
    provider = current_user[:provider]
    uid = current_user[:uid]
    if al = policy_allow_list[provider]
      if al['user'] && !al['user'].include?(uid)
        next false
      end
    end
  end

  true
}

# Not implemented:
# NGX_OMNIAUTH_GITHUB_KEY
# NGX_OMNIAUTH_GITHUB_SECRET
# NGX_OMNIAUTH_GOOGLE_HD

# -----------------------------------------------------------------------------

dev = arg_dev || arg_rack_env == 'development'
test = arg_rack_env == 'test'

# We intentionally allow GET for login, knowing CVE-2015-9284.
OmniAuth.config.allowed_request_methods = [:get, :post]
if Gem::Version.new(OmniAuth::VERSION) >= Gem::Version.new("2.0.0")
  OmniAuth.config.silence_get_warning = true
end

if test
  dev = true
  warn 'TEST MODE'
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[:developer] = {provider: 'developer', uid: '42', info: {}}
end

if !dev && !arg_session_secret
  raise 'You should specify $NGX_OMNIAUTH_SESSION_SECRET'
end

use(
  # Rack::Session::Cookie,
  Rack::Session::Pool,
  key:          arg_session_cookie_name,
  expire_after: arg_session_cookie_timeout,
  secret:       arg_session_secret || 'ngx_omniauth_secret_dev',
  # old_secret:   ENV['NGX_OMNIAUTH_SESSION_SECRET_OLD'], 
  secure: arg_session_secure
)

providers = []

use OmniAuth::Builder do
  if ENV['NGX_OMNIAUTH_GITHUB_KEY'] && ENV['NGX_OMNIAUTH_GITHUB_SECRET']
    require 'omniauth-github'
    gh_client_options = {}
    if ENV['NGX_OMNIAUTH_GITHUB_HOST']
      gh_client_options[:site] = "#{ENV['NGX_OMNIAUTH_GITHUB_HOST']}/api/v3"
      gh_client_options[:authorize_url] = "#{ENV['NGX_OMNIAUTH_GITHUB_HOST']}/login/oauth/authorize"
      gh_client_options[:token_url] = "#{ENV['NGX_OMNIAUTH_GITHUB_HOST']}/login/oauth/access_token"
    end

    gh_scope = ''
    if ENV['NGX_OMNIAUTH_GITHUB_TEAMS']
      gh_scope = 'read:org'
    end

    provider :github, ENV['NGX_OMNIAUTH_GITHUB_KEY'], ENV['NGX_OMNIAUTH_GITHUB_SECRET'], client_options: gh_client_options, scope: gh_scope
    providers << :github
  end

  if arg_google_key && arg_google_secret
    require 'omniauth-google-oauth2'
    provider :google_oauth2, arg_google_key, arg_google_secret, hd: arg_google_hd
    providers << :google_oauth2
  end

  if dev
    provider :developer
    providers << :developer
  end
end

run NginxOmniauthAdapter.app(
  providers: providers,
  provider_http_header: arg_provider_http_header,
  secret: arg_secret,
  host: arg_host,
  allowed_app_callback_url: arg_allowed_app_callback_url,
  allowed_back_to_url: arg_allowed_back_to_url,
  app_refresh_interval: arg_app_refresh_interval,
  adapter_refresh_interval: arg_adapter_refresh_interval,
  policy_proc: policy_proc,
  on_login_proc: proc {
    auth = env['omniauth.auth']
    case auth[:provider]
    when 'github'
      if gh_teams
        api_host = ENV['NGX_OMNIAUTH_GITHUB_HOST'] ? "#{ENV['NGX_OMNIAUTH_GITHUB_HOST']}/api/v3" : "https://api.github.com"
        current_user_data[:gh_teams] = open("#{api_host}/user/teams", 'Authorization' => "token #{auth['credentials']['token']}") { |io|
          JSON.parse(io.read).map {|_| "#{_['organization']['login']}/#{_['slug']}" }.select { |team| gh_teams.include?(team) }
        }
      end
    end

    true
  },
)
