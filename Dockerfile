FROM jekyll/minimal:pages as p
ADD . /srv/jekyll
RUN  bundle update && bundle install && jekyll build
FROM justcy/nginx:latest
COPY --from=p /srv/jekyll/_site /usr/share/nginx/html/