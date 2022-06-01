#!/bin/sh

if [ -z ${CERT} ];then
    echo "[Error]: Unable to find the CERT environment variable set"
    exit 1;
elif [ -z ${KEY} ];then
    echo "[Error]: Unable to find the KEY environment vairable set"
    exit 2;
elif [ -z ${HOST} ];then
    echo "[Error]: Unable to find the HOST environment variable set"
    exit 3;
elif [ -z ${PORT} ];then
    echo "[Error]: Unable to find PORT environment variable set"
    exit 4;
fi

if [ ! -f  ${CERT} ];then
    echo "[Error]: Unable to find the $CERT"
    exit 5;
elif [ ! -f ${KEY} ];then
    echo "[Error]: Unable to find the $KEY"
    exit 6;
fi



gunicorn --certfile  "${CERT}"  --keyfile "${KEY}"   -b   "${HOST}:${PORT}"  webserver:admission_controller
