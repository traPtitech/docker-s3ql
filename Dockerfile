FROM python:3.12-alpine AS build

ARG S3QL_VERSION=5.2.3

WORKDIR /app
COPY requirements.txt /app
RUN apk --no-cache add curl gnupg jq bzip2 g++ make pkgconfig fuse3-dev sqlite-dev libffi-dev openssl-dev cargo
RUN pip install --user --ignore-installed -r requirements.txt
RUN gpg2 --batch --keyserver keyserver.ubuntu.com --recv-key 0xD113FCAC3C4E599F
ARG FILE="s3ql-$S3QL_VERSION"
ARG URL="https://github.com/s3ql/s3ql/releases/download/$FILE/$FILE.tar.gz"
RUN set -x; \
  curl -sfL "$URL" -o "/tmp/$FILE.tar.gz" \
  && tar -xmf "/tmp/$FILE.tar.gz" -C /tmp
WORKDIR /tmp/$FILE
RUN python3 setup.py build_ext --inplace \
  && python3 setup.py install --user

FROM python:3.12-alpine
RUN apk --no-cache add fuse3 psmisc
COPY --from=build /root/.local/bin/ /usr/local/bin/
COPY --from=build /root/.local/lib/ /usr/local/lib/
COPY ./authfile.sh ./entrypoint.sh ./mount.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/*.sh
ENV MOUNTPOINT=/s3ql
VOLUME /root/.s3ql
HEALTHCHECK CMD ["/bin/sh","-c","s3qlstat --quiet $MOUNTPOINT"]
ENTRYPOINT ["/bin/sh","/usr/local/bin/entrypoint.sh"]
CMD ["/bin/sh","/usr/local/bin/mount.sh"]
