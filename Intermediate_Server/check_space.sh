#! /bin/bash

BASE_PATH=`grep "base_path=*" config | awk -F'=' '{print $2}'`

# calculating used percentage of disk
used_percentage=`df --output=pcent ${BASE_PATH} | head -2 | tail -1 | sed 's/%//' | sed 's/ //'`

limit=`grep "disk_usage_alert_limit*" config | awk -F'=' '{print $2}'`

if [ $used_percentage -gt $limit ]; then
	# send mail about low space to admin
	bash mail_notification.sh alert.template "Low Disk Space" "Disk Space getting low"
fi

