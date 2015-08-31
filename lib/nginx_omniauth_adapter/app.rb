require 'sinatra/base'
require 'uri'
require 'time'
require 'openssl'
require 'json'

module NginxOmniauthAdapter
  class App < Sinatra::Base
    CONTEXT_RACK_ENV_NAME = 'nginx-oauth2-adapter'.freeze
    SESSION_PASS_CIPHER_ALGORITHM = 'aes-256-gcm'.freeze

    set :root, File.expand_path(File.join(__dir__, '..', '..', 'app'))

    def self.initialize_context(config)
      {}.tap do |ctx|
        ctx[:config] = config
      end
    end

    def self.rack(config={})
      klass = self

      context = initialize_context(config)
      app = lambda { |env|
        env[CONTEXT_RACK_ENV_NAME] = context
        klass.call(env)
      }
    end

    helpers do
      def context
        request.env[CONTEXT_RACK_ENV_NAME]
      end

      def adapter_config
        context[:config]
      end

      def adapter_host
        adapter_config[:host]
      end

      def providers
        adapter_config[:providers]
      end

      def allowed_back_to_url
        adapter_config[:allowed_back_to_url] || /./
      end

      def allowed_app_callback_url
        adapter_config[:allowed_app_callback_url] || /./
      end

      def default_back_to
        # TODO:
        '/'
      end

      def sanitized_back_to_param
        p params[:back_to]
        if allowed_back_to_url === params[:back_to]
          params[:back_to]
        else
          nil
        end
      end

      def sanitized_app_callback_param
        p params[:callback]
        if allowed_app_callback_url === params[:callback]
          params[:callback]
        else
          nil
        end
      end

      def current_user
        session[:user]
      end

      def current_authorized_at
        session[:authorized_at] && Time.xmlschema(session[:authorized_at])
      end

      def app_refresh_interval
        adapter_config[:app_refresh_interval] || (60 * 60 * 24)
      end

      def adapter_refresh_interval
        adapter_config[:adapter_refresh_interval] || (60 * 60 * 24 * 30)
      end

      def app_authority_expired?
        app_refresh_interval && current_user && (Time.now - current_authorized_at) > app_refresh_interval
      end

      def adapter_authority_expired?
        adapter_refresh_interval && current_user && (Time.now - current_authorized_at) > adapter_refresh_interval
      end

      def update_session!(auth = nil)
        unless session[:app_callback]
          raise '[BUG] app_callback is missing'
        end

        common_session = {
          authorized_at: Time.now.xmlschema,
        }

        if auth
          common_session[:user] = {
            uid: auth[:uid],
            info: auth[:info],
            provider: auth[:provider],
          }
        else
          common_session[:user] = session[:user]
        end

        adapter_session = common_session.merge(
          side: :adapter,
        )

        app_session = common_session.merge(
          side: :app,
          back_to: session.delete(:back_to),
        )

        session.merge!(adapter_session)

        session_param = encrypt_session_param(app_session)
        redirect "#{session.delete(:app_callback)}?session=#{session_param}"
      end

      def secret_key
        context[:secret_key] ||= begin
          if adapter_config[:secret]
            adapter_config[:secret].unpack('m*')[0]
          else
            cipher = OpenSSL::Cipher.new(SESSION_PASS_CIPHER_ALGORITHM)
            warn "WARN: :secret not set; generating randomly."
            warn "      If you'd like to persist, set `openssl rand -base64 #{cipher.key_len}` . Note that you have to keep it secret."

            OpenSSL::Random.random_bytes(cipher.key_len)
          end
        end
      end

      def encrypt_session_param(session_param)
        iv = nil
        cipher ||= OpenSSL::Cipher.new(SESSION_PASS_CIPHER_ALGORITHM).tap do |c|
          c.encrypt
          c.key = secret_key
          c.iv = iv = c.random_iv
          c.auth_data = ''
        end

        plaintext = Marshal.dump(session_param)

        ciphertext = cipher.update(plaintext)
        ciphertext << cipher.final

        URI.encode_www_form_component([{
          "iv" => [iv].pack('m*'),
          "data" => [ciphertext].pack('m*'),
          "tag" => [cipher.auth_tag].pack('m*'),
        }.to_json].pack('m*'))
      end

      def decrypt_session_param(raw_data)
        data = JSON.parse(raw_data.unpack('m*')[0])

        cipher ||= OpenSSL::Cipher.new(SESSION_PASS_CIPHER_ALGORITHM).tap do |c|
          c.decrypt
          c.key = secret_key
          c.iv = data['iv'].unpack('m*')[0]
          c.auth_data = ''
          c.auth_tag = data['tag'].unpack('m*')[0]
        end

        plaintext = cipher.update(data['data'].unpack('m*')[0])
        plaintext << cipher.final

        Marshal.load(plaintext)
      end

    end

    get '/' do
      content_type :text
      "NginxOmniauthAdapter #{NginxOmniauthAdapter::VERSION}"
    end

    get '/test' do
      unless current_user
        halt 401
      end

      if app_authority_expired?
        halt 401
      end

      headers(
        'x-ngx-oauth-provider' => current_user[:provider],
        'x-ngx-oauth-user' => current_user[:uid],
        'x-ngx-oauth-info' => [current_user[:info].to_json].pack('m*'),
      )

      content_type :text
      'ok'.freeze
    end

    get '/initiate' do
      back_to = URI.encode_www_form_component(request.env['HTTP_X_NGX_OAUTH_INITIATE_BACK_TO'])
      callback = URI.encode_www_form_component(request.env['HTTP_X_NGX_OAUTH_INITIATE_CALLBACK'])
      redirect "#{adapter_host}/auth?back_to=#{back_to}&callback=#{callback}"
    end

    get '/auth' do
      # TODO: choose provider
      session[:back_to] = sanitized_back_to_param
      session[:app_callback] = sanitized_app_callback_param
      p [:auth, session]

      if current_user
        p [:auth, :update]
        update_session!
      else
        p [:auth, :redirect]
        redirect "#{adapter_host}/auth/#{providers[0]}"
      end
    end

    omniauth_callback = proc do
      update_session! env['omniauth.auth']
    end
    get '/auth/:provider/callback', &omniauth_callback
    post '/auth/:provider/callback', &omniauth_callback

    get '/callback' do # app side
      app_session = decrypt_session_param(params[:session])
      session.merge!(app_session)
      redirect session.delete(:back_to)
    end
  end
end