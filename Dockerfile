FROM jekyll/minimal:pages as builder
ADD . /srv/jekyll
RUN  rm -rf ./Gemfile.lock && bundle update && bundle install && jekyll build -d /tmp/_site -V
FROM scratch
COPY --from=builder /tmp/_site  /blog
COPY --from=hello-world /hello  /
CMD ["/hello > /dev/null"]