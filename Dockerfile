FROM alpine:latest

RUN apk update \
    && apk upgrade \
    && apk add --no-cache ca-certificates ca-certificates-bundle coreutils tar jq wget unzip libqrencode tzdata nginx

ADD demo.zip /demo.zip
ADD entrypoint.sh /entrypoint.sh
CMD rm -rf /etc/localtime
CMD ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
CMD echo $HEROKU_APP_NAME > /appname
CMD chmod +x /entrypoint.sh
CMD sh -x /entrypoint.sh
