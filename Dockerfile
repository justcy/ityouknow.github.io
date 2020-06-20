FROM jekyll/minimal:pages as builder
ADD . /srv/jekyll
RUN  rm -rf ./Gemfile.lock && bundle update && bundle install && jekyll build -d /srv/jekyll/_site
FROM justcy/nginx:latest
COPY --from=builder /srv/jekyll/_site /usr/share/nginx/html/