FROM jekyll/minimal:pages as builder
ENV JEKYLL_GITHUB_TOKEN=f4025f630f8f10e240ea970f4bbfc0eb1f5459a4
ADD . /srv/jekyll
RUN  rm -rf /srv/jekyll/_site /srv/jekyll/Gemfile.lock && bundle update && bundle install \
     && jekyll build
FROM justcy/nginx:latest
COPY --from=builder /srv/jekyll/_site /usr/share/nginx/html/