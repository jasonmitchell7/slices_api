FROM ruby:2.2.3

RUN apt-get update -yqq \
  && apt-get install -yqq --no-install-recommends \
    postgresql-client \
    nodejs \
  && apt-get -q clean \
  && rm -rf /var/lib/apt/lists

WORKDIR /usr/src/api
COPY Gemfile* ./
RUN ["bundle", "install"]
COPY . .

EXPOSE 3000
CMD ["rails", "server", "-p", "3000", "-b", "0.0.0.0"]
