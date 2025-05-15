#!/bin/bash

USER="ubuntu"
CONFIG_S3="/home/$USER/.s3cfg"
LOG_FILE="/var/log/infrastructure_setting.log"

#--- логирование ----------------------------------------------------------------------------------

function LOG() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') $1" | tee -a $LOG_FILE
}

function ERROR() {
    LOG "[ERR] $1"
}

function INFO() {
    LOG "[INF] $1"
}

#--- копирование s3-to-s3 -------------------------------------------------------------------------

INFO "s3cmd installation"
apt-get update
apt-get install -y s3cmd

INFO "s3cmd configuration"
cat <<EOF > $CONFIG_S3
[default]
access_key = ${access_key}
secret_key = ${secret_key}
host_base = storage.yandexcloud.net
host_bucket = %(bucket)s.storage.yandexcloud.net
use_https = True
EOF

chown $USER: $CONFIG_S3
chmod 600 $CONFIG_S3

INFO "copying files from the source bucket to the destination bucket..."
s3cmd --config=$CONFIG_S3 \
      --acl-public \
      -r sync \
      s3://${src_bucket}/ \
      s3://${dst_bucket}/ 

if [ $? -eq 0 ]; then
    count=$(s3cmd ls --config=$CONFIG_S3 s3://${dst_bucket}/ | wc -l)
    INFO "copying is complete: $count files successfully copied to the bucket \"${dst_bucket}\""
else
    ERROR "an error occurred when copying files to bucket \"${dst_bucket}\""
fi