#! /bin/bash

# environment variable reading from config file
BASE_PATH=`grep "base_path=*" config | awk -F'=' '{print $2}'`

# function to check required directory and creating if needed

if [ ! -d ${BASE_PATH}/logs_backup ]; then
	mkdir ${BASE_PATH}/logs_backup 2>&1 | tee -a log.txt
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
		bash mail_notification.sh alert.template "Logs backup error" "Error in creating directory logs_backup. Please check!"
	fi
fi


# reading text file in logs folder and then recombining parts
if [ `ls ${BASE_PATH}/logs/*.txt | head -1` ]; then

	for file in `ls ${BASE_PATH}/logs/*.txt`;
	do
		
		total_files=`grep "total_parts*" $file | awk -F'=' '{print $2}'`
		tar_name=`basename $file | sed -e 's/.txt//'`
		files_present=`ls ${BASE_PATH}/logs/$tar_name.split* | wc -l`

		if [ $total_files -eq $files_present ]; then

			# recombine all parts
			cat ${BASE_PATH}/logs/$tar_name.split* > ${BASE_PATH}/logs/$tar_name
			
			if [ $? -eq 0 ]; then
				rm ${BASE_PATH}/logs/$tar_name.split*
			fi
			
			md5sum=`grep "md5sum*" $file | awk -F'=' '{print $2}'`
			
			md5sum_present=`md5sum ${BASE_PATH}/logs/$tar_name | awk '{ print $1 }'`
			
			if [ $md5sum != $md5sum_present ]; then
				bash mail_notification.sh alert.template "Logs backup error" "md5sum error in file `echo $tar_name`"
			else
				# removing .txt file having archive information
				rm ${BASE_PATH}/logs/$tar_name.txt
				# file ready to be processed
				# tar file for sending to backup
				mv ${BASE_PATH}/logs/$tar_name ${BASE_PATH}/logs_backup/$tar_name
			fi
		fi

	done

else
	bash mail_notification.sh alert.template "Logs backup error" "No new file for backup"

fi