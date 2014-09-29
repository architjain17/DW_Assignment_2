#! /bin/bash


# grabbing parameters
servername=app1
BASE_PATH=`grep "base_path=*" config | awk -F'=' '{print $2}'`
tar_name=${servername}`date +"%F"`.tar.gz

echo $BASE_PATH

tar -cz -C ${BASE_PATH}/logs_shipping/ -f ${BASE_PATH}/logs_shipping/${tar_name} `find ${BASE_PATH}/logs_shipping/raw_*_${servername}_db.log.rotated.*.log -printf "%f\n"` 2>&1 | tee -a ../log.txt
tar_exit_status=${PIPESTATUS[0]}
	