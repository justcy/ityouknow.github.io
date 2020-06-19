FROM jekyll/minimal:pages as builder
ADD . /srv/jekyll
RUN  rm -rf /srv/jekyll/Gemfile.lock && bundle update && bundle install \
     && jekyll build
FROM justcy/nginx:latest
COPY --from=builder /srv/jekyll/_site /usr/share/nginx/html/