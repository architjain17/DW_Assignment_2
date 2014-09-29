#! /bin/bash

# environment variable reading from config file
BASE_PATH=`grep "base_path=*" config | awk -F'=' '{print $2}'`
SCP_DEST_PATH=`grep "scp_dest_path=*" config | awk -F'=' '{print $2}'`

# function to handle signals
func_interrupt_handler()
{
    # code for sending email to report interrupt
    echo bye
    bash mail_notification.sh alert.template "Logs shipping error" "Shipping Script interrupted"
    exit 1
}

# function to check error in any command

func_check_error ()
{
	if [ $1 -ne 0 ]; then
		bash mail_notification.sh alert.template "Logs shipping error" "$2"
	fi
}

# function to check if space is available on disk to continue the script
func_check_space ()
{
	free_space=`df --output=avail ${BASE_PATH} | head -2 | tail -1`

	files_size=`du -s ${BASE_PATH} | sed -e 's/\([0-9]*\).*/\1/'`

	if [ $free_space -lt $files_size ]; then
		# send mail about low space to admin
		bash mail_notification.sh alert.template "Logs shipping error" "Low disk space available, unable to continue shipping script"
		exit
	fi
}

# function to check required directories and creating if needed
func_create_directories ()
{		
	if [ ! -d ${BASE_PATH}/logs_backup/logs_process ]; then
		mkdir ${BASE_PATH}/logs_backup/logs_process 2>&1 | tee -a log.txt
		func_check_error ${PIPESTATUS[0]} "Error in creating directory logs_backup/logs_process. Please check!"
	fi

	if [ ! -d ${BASE_PATH}/logs_backup/logs_backup ]; then
		mkdir ${BASE_PATH}/logs_backup/logs_backup 2>&1 | tee -a log.txt
		func_check_error ${PIPESTATUS[0]} "Error in creating directory logs_backup/logs_backup. Please check!"
	fi

	if [ ! -d ${BASE_PATH}/logs_backup/logs_failed ]; then
		mkdir ${BASE_PATH}/logs_backup/logs_failed 2>&1 | tee -a log.txt
		func_check_error ${PIPESTATUS[0]} "Error in creating directory logs_backup/logs_failed. Please check!"
	fi 
}

# function which perform cleanup process when script skips a set of files
func_cleanup_on_skip ()
{
	
	for file in `ls ${BASE_PATH}/logs_backup/logs_process/$tar_name.split*`;
	do
		filename=`basename $file`

		# make database log entry of these files
		echo ship,failure,`date +%F" "%T`,$filename >> database.log

		# make entry of these files in run_details_ship_failure so that name of all files are sent via email
		echo $filename >> run_details_ship_failure.txt

	done

	# move remaining files from logs_process folder to logs_failed folder as script will not try sending further files
	mv ${BASE_PATH}/logs_backup/logs_process/$tar_name.split* ${BASE_PATH}/logs_backup/logs_failed/ 2>&1 | tee -a log.txt
	func_check_error ${PIPESTATUS[0]} "Error in moving files from logs_backup/logs_process folder to logs_backup/logs_failed folder. Please check!"

}

func_check_exit_status ()
{
	if(( $1 == 2 )); then
		echo "SCP key verification failed!"
		# sending mail to notify SCP key verification failure
		bash mail_notification.sh alert.template "Logs shipping error" "SCP key verfication failed"
		break
	fi

	if(( $1 == 3 )); then
		echo "Connection failure!"
		# sending mail to notify no internet connection
		bash mail_notification.sh alert.template "Logs shipping error" "No Internet Connection Found"
		break
	fi
}


func_push ()
{
	# grabbing parameters
	file=$1

	# grabbing parameters from config file
	destination_server_ip=`grep "destination_server_ip*" config | awk -F'=' '{print $2}'`
	
	# making a return parameter
	return_value=0

	filename=`basename $file`
	scp ${BASE_PATH}/logs_backup/logs_process/$filename source@$destination_server_ip:${SCP_DEST_PATH} >/dev/null 2>&1 | tee -a log.txt
	
	exit_status=`echo ${PIPESTATUS[0]}`
		
		if [ $exit_status -eq 0 ]; then

			echo `date +"%F,%T,"`$file",message: transferred successfully" >> log.log
			# echo "ship,success,"`date +"%F,%T,"`$file >> log.log
			status="success"
			echo $filename >> run_details_ship_success.txt
			
			# move file to logs_backup
			mv ${BASE_PATH}/logs_backup/logs_process/$filename ${BASE_PATH}/logs_backup/logs_backup/$filename >/dev/null 2>&1 | tee -a log.txt
			func_check_error ${PIPESTATUS[0]} "Error in moving files from logs_process folder to logs_backup. Please check!"

			return_value=0

		else

			# checking if key exchange failed in scp
			if [ $exit_status -eq 67 ]; then

				# error in scp

				echo `date +"%F,%T,"`"severity level:2,"$file",message: error in scp connection" >> log.log
				
				# exit status 2 means an key error in scp
				return_value=2

			else

				# checking internet connectivity with destination server to decide whether to continue or not
				# uncomment next line and pass address of destination server to check connectivity
				ping -q -c 1 $destination_server_ip >/dev/null 2>&1 | tee -a log.txt

				if [ "${PIPESTATUS[0]}" != 0 ]; then
				  # stop sending rest of files
				  status="failure"
				  echo `date +"%F,%T,"`"severity level:3,"$file",message: no internet connection found" >> log.log

				  # status 3 means no internet connection found
				  return_value=3
				
				else

				# error in scp

				echo `date +"%F,%T,"`"severity level:1,"$file",message: error!" >> log.log
				
				# exit status 1 means an error occured
				return_value=1

				fi
			fi

			status="failure"
			echo $filename >> run_details_ship_failure.txt

			# move file to logs_failed
			mv ${BASE_PATH}/logs_backup/logs_process/$filename ${BASE_PATH}/logs_backup/logs_failed/$filename >/dev/null 2>&1 | tee -a log.txt
			func_check_error ${PIPESTATUS[0]} "Error in moving files from logs_process folder to logs_failed. Please check!"

		fi

		# making entry in database
		echo ship,$status,`date +%F" "%T`,$filename >> database.log

		echo $return_value
}


func_push_failed_files()
{
	# retrying failed parts of tar files
	for file in `ls ${BASE_PATH}/logs_backup/logs_failed/*.split* 2>&1 | tee -a log.txt`;
	do
		exit_status=`func_push $file`
			
		func_check_exit

		func_check_exit_status $exit_status
	done

	# retrying txt file having details of tar files
	for file in `ls ${BASE_PATH}/logs_failed/*.txt 2>&1 | tee -a log.txt`;
	do
		exit_status=`func_push $file`
			
		func_check_exit_status $exit_status
	done

}


func_push_rotated_log_files()
{
	# grabbing parameters from config file
	size_of_one_part=`grep "size_of_one_part*" config | awk -F'=' '{print $2}'`
	
	for file in ${BASE_PATH}/logs_backup/logs/*.tar.gz
	do
		tar_name=`basename $file`

		mv ${BASE_PATH}/logs_backup/logs/$tar_name ${BASE_PATH}/logs_backup/logs_process 2>&1 | tee -a log.txt
		func_check_error ${PIPESTATUS[0]} "Error in moving files from logs_backup/logs folder to logs_backup/logs_process. Please check!"

		# storing md5sum of archive
		echo "md5sum=" >> log.txt
		md5sum=`md5sum ${BASE_PATH}/logs_backup/logs_process/$tar_name | awk '{ print $1 }' 2>&1 | tee -a log.txt`
		echo "md5sum="$md5sum  > ${BASE_PATH}/logs_backup/logs_process/$tar_name.txt

		# spliting file into smaller files of size 1 GB each in order to ship
		split -b $size_of_one_part -d ${BASE_PATH}/logs_backup/logs_process/$tar_name ${BASE_PATH}/logs_backup/logs_process/$tar_name.split 2>&1 | tee -a log.txt
		split_exit_status=${PIPESTATUS[0]}
		func_check_error $split_exit_status "Error in splitting tar file. Please check!"
	
		if [ $split_exit_status -eq 0 ]; then
			rm ${BASE_PATH}/logs_backup/logs_process/$tar_name 2>&1 | tee -a log.txt
			func_check_error ${PIPESTATUS[0]} "Error in removing files from logs_backup/logs_process folder. Please check!"
		fi

		total_parts=`ls ${BASE_PATH}/logs_backup/logs_process/$tar_name.split* | wc -l`

		# reading current files
		for file in `ls ${BASE_PATH}/logs_backup/logs_process/$tar_name.split*`;
		do
			
			exit_status=`func_push $file`
			
			if [ $exit_status -eq 2 ] || [ $exit_status -eq 3 ]; then
				func_cleanup_on_skip
			fi
			
			func_check_exit_status $exit_status
		
		done
		
		# storing total parts of archive and sending it
		
		echo "total_parts="$total_parts >> ${BASE_PATH}/logs_backup/logs_process/$tar_name.txt
		scp ${BASE_PATH}/logs_backup/logs_process/$tar_name.txt source@$destination_server_ip:${SCP_DEST_PATH} 2>&1 | tee -a log.txt
		scp_exit_status=${PIPESTATUS[0]}
		func_check_error $scp_exit_status "Error while transferring file having shipping details through SCP. Please check!"	
			
		if [ $scp_exit_status -eq 0 ]; then 
			mv ${BASE_PATH}/logs_backup/logs_process/$tar_name.txt ${BASE_PATH}/logs_backup/logs_backup/ 2>&1 | tee -a log.txt
			func_check_error ${PIPESTATUS[0]} "Error in moving files from logs_backup/logs_process folder to logs_backup/logs_backup. Please check!"
		else
			mv ${BASE_PATH}/logs_backup/logs_process/$tar_name.txt ${BASE_PATH}/logs_backup/logs_failed/ 2>&1 | tee -a log.txt
			func_check_error ${PIPESTATUS[0]} "Error in moving files from logs_backup/logs_process folder to logs_backup/logs_failed. Please check!"
		fi



	done
}


# script code starts here

start=`date +%s`

# creating required directories

if [ -d ${BASE_PATH}/logs_backup ]; then 
	func_create_directories
fi

# setting trap for the script
trap func_interrupt_handler SIGINT SIGQUIT SIGTERM

# grabbing parameters
servername=`grep "servername=*" config | awk -F'=' '{print $2}'` 
destination_server_ip=`grep "destination_server_ip=*" config | awk -F'=' '{print $2}'`

# check if appropriate disk space available to continue script is present or not
func_check_space

# check if failed files present in folder logs_failed
if [ `ls ${BASE_PATH}/logs_backup/logs_failed/*.split* 2> /dev/null | head -1` ]; then
	# retry sending failed files
	func_push_failed_files
fi

# check if new log files present in folder logs_failed
if [ `ls ${BASE_PATH}/logs_backup/logs/*.tar.gz 2> /dev/null | head -1` ]; then
	# sending new rotated log files
	func_push_rotated_log_files
fi

# grabbing parameters from config file
local_sql_server_ip_address=`grep "local_sql_server_ip_address*" config | awk -F'=' '{print $2}'`
local_sql_server_username=`grep "local_sql_server_username*" config | awk -F'=' '{print $2}'`
local_sql_server_password=`grep "local_sql_server_password*" config | awk -F'=' '{print $2}'`
local_sql_server_database_name=`grep "local_sql_server_database_name*" config | awk -F'=' '{print $2}'`

if [ -f run_details_ship_success.txt ] || [ -f run_details_ship_failure.txt ]; then
	# making entry of log in database
	bcp [${local_sql_server_database_name}].shipping.log in "database.log" -S $local_sql_server_ip_address -U $local_sql_server_username -P $local_sql_server_password -f database_log.fmt > /dev/null 2>&1 | tee -a log.txt

	# if bcp is succesful then remove database.log file else send error mail
	if [ ${PIPESTATUS[0]} -eq 0 ]; then
		rm database.log
	else
		bash mail_notification.sh alert.template "Logs shipping error" "Error occured with SQL Server having IP address `echo $local_sql_server_ip_address`. Log details is not entered into database, it will be retried at next run"
	fi
fi 

# if both files are present
if [ -f run_details_ship_success.txt ] && [ -f run_details_ship_failure.txt ]; then
	bash mail_notification.sh success_failure.template

# if only success file is present
elif [ -f run_details_ship_success.txt ] && [ ! -f run_details_ship_failure.txt ]; then
	bash mail_notification.sh success.template

# if only failure file is present
elif [ ! -f run_details_ship_success.txt ] && [ -f run_details_ship_failure.txt ]; then
	bash mail_notification.sh failure.template

# both files are not present
else
	bash mail_notification.sh alert.template "Logs shipping error" "No new rotated log file or failed files to be transferred"
fi

end=`date +%s`

# calculating script runtime
runtime=$((end-start))

# logging execution time into a log file
echo `date +"%F,%T,"`"script running time(in seconds):"$runtime >> script_runtime.txt