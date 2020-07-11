FROM jekyll/minimal:pages as builder
ADD . /srv/jekyll
RUN  rm -rf ./Gemfile.lock && bundle update && bundle install && jekyll build -d /tmp/_site -V
FROM justcy/nginx:latest
COPY --from=builder /tmp/_site  /usr/share/nginx/html/