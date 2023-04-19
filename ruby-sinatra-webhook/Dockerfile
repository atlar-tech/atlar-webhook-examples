FROM ruby:3

WORKDIR /app
COPY Gemfile .
RUN bundle install
COPY app.rb app.rb
CMD ["ruby", "app.rb"]
