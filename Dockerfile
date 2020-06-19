FROM jekyll/minimal:pages as p
ADD . /srv/jekyll
RUN  rm -rf /srv/jekyll/Gemfile.lock && bundle update && bundle install \
     && jekyll build && pwd
FROM justcy/nginx:latest
COPY --from=p /srv/jekyll/_site /usr/share/nginx/html/