FROM ruby:2.7

RUN apt-get update -qq && apt-get install -y postgresql-client
WORKDIR /esm_bot
COPY esm.gemspec /esm_bot/esm.gemspec
COPY Gemfile /esm_bot/Gemfile
COPY Gemfile.lock /esm_bot/Gemfile.lock
COPY . /esm_bot
RUN bundle install
EXPOSE 3001
EXPOSE 3002
