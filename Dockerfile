FROM jekyll/minimal:pages as builder
ADD . /srv/jekyll
RUN  rm -rf ./Gemfile.lock && bundle update && bundle install && jekyll build -d /tmp/_site -V
FROM scratch
COPY --from=builder /tmp/_site  /blog
COPY --from=alpine:latest /bin/sh /bin/sh
CMD ["/bin/sh"]