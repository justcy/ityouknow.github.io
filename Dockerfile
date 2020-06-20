FROM jekyll/minimal:pages as builder
ADD . /srv/jekyll
RUN  rm -rf ./Gemfile.lock && bundle update && bundle install && sudo jekyll build -d /tmp/_site
FROM justcy/nginx:latest
COPY --from=builder /tmp/_site /usr/share/nginx/html/