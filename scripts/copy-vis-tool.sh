#!/usr/bin/env bash
set -ex

PROXY_CONTAINER=montagu-proxy
ORDERLY_CONTAINER=orderly-web-orderly

ORDERLY_REPORT_2020=paper-first-public-app
ORDERLY_REPORT_2021=paper-second-public-app

ORDERLY_ID_2020=20210323-091557-54aa64f1
ORDERLY_ID_2021=20210713-133411-1133b34e

ORDERLY_PATH_2020="/orderly/archive/$ORDERLY_REPORT_2020/$ORDERLY_ID_2020"
ORDERLY_PATH_2021="/orderly/archive/$ORDERLY_REPORT_2021/$ORDERLY_ID_2021"
WWW_ROOT=/usr/share/nginx/html

docker exec -it $PROXY_CONTAINER mkdir -p $WWW_ROOT/2020/visualisation
docker exec -it $PROXY_CONTAINER mkdir -p $WWW_ROOT/2021/visualisation

mkdir -p 2020/visualisation
mkdir -p 2021/visualisation

docker cp $ORDERLY_CONTAINER:$ORDERLY_PATH_2020/. 2020/visualisation
docker cp $ORDERLY_CONTAINER:$ORDERLY_PATH_2021/. 2021/visualisation


docker cp 2020/visualisation/. $PROXY_CONTAINER:$WWW_ROOT/2020/visualisation
docker cp 2021/visualisation/. $PROXY_CONTAINER:$WWW_ROOT/2021/visualisation
