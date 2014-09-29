#! /bin/bash

BASE_PATH=`grep "base_path=*" config | awk -F'=' '{print $2}'`
tar_name=app12014-08-29.tar.gz

tar -x -C ${BASE_PATH}/logs_consume -f ${BASE_PATH}/logs_consume/$tar_name
