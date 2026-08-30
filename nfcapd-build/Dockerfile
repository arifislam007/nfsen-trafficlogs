FROM alpine:3.20
RUN apk add --no-cache nfdump
VOLUME /data
EXPOSE 2055/udp
ENTRYPOINT ["nfcapd"]
