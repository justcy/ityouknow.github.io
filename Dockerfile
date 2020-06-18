FROM jekyll/builder:latest as builder
ENV JEKYLL_GITHUB_TOKEN=f4025f630f8f10e240ea970f4bbfc0eb1f5459a4
ADD . /srv/jekyll
RUN  bundle update && bundle install \
     && jekyll build
FROM justcy/nginx:latest
COPY --from=builder /srv/jekyll/_site /usr/share/nginx/html/