FROM ruby:3.2.2

ENV DEBIAN_FRONTEND noniteractive

WORKDIR /esm_bot

RUN apt-get update -qq \
    && apt-get install -yqq \
    postgresql-client build-essential software-properties-common libssl-dev

COPY Gemfile Gemfile.lock ./

RUN gem install bundler && bundle install

RUN apt-get clean -yqq && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY bin/docker-entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

COPY . ./

EXPOSE 3001 3002

ENTRYPOINT ["docker-entrypoint.sh"]
