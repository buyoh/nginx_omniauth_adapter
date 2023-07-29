FROM ruby:2.7

ENV LANG C.UTF-8

RUN mkdir -p /app

ADD Gemfile* /app/
ADD nginx_omniauth_adapter.gemspec /app/
ADD * /app/

RUN cd /app && git init
RUN mkdir -p /app/lib/nginx_omniauth_adapter
ADD lib/nginx_omniauth_adapter/version.rb /app/lib/nginx_omniauth_adapter/version.rb
RUN cd /app \
  && bundle config set path vendor/bundle
  # && bundle config set without 'development test'
RUN cd /app && bundle install

WORKDIR /app
ADD . /app
# RUN cp -a /app/vendor /app/
# RUN rm -f /app/.ruby-version

EXPOSE 8080
ENV RACK_ENV=production
CMD ["bundle", "exec", "rackup", "-p", "8080", "-o", "0.0.0.0", "config.ru"]
