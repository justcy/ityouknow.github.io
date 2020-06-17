FROM jekyll/builder:latest as builder
ADD . /srv/jekyll
RUN  bundle update && bundle install \
     && jekyll build
FROM justcy/nginx:latest
COPY --from=builder /srv/jekyll/_site /usr/share/nginx/html/