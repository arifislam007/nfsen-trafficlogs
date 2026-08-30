FROM alpine:3.20
RUN apk add --no-cache rsyslog
VOLUME /var/log/remote
EXPOSE 514/udp 514/tcp
ENTRYPOINT ["rsyslogd", "-n", "-f", "/etc/rsyslog.conf"]
