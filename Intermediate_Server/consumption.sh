#! /bin/bash

# environment variable reading from config file
BASE_PATH=`grep "base_path=*" config | awk -F'=' '{print $2}'`

# grabbing parameters from config file
servername=`grep "servername=*" config | awk -F'=' '{print $2}'` 
analytics_sql_server_ip_address=`grep "analytics_sql_server_ip_address*" config | awk -F'=' '{print $2}'`
analytics_sql_server_username=`grep "analytics_sql_server_username*" config | awk -F'=' '{print $2}'`
analytics_sql_server_password=`grep "analytics_sql_server_password*" config | awk -F'=' '{print $2}'`
analytics_sql_server_database_name=`grep "analytics_sql_server_database_name*" config | awk -F'=' '{print $2}'`

# function to handle signals
func_interrupt_handler()
{
    # code for sending email to report interrupt
    echo bye
    bash mail_notification.sh alert.template "Logs consumption error" "Consumption Script interrupted"
    exit 1
}


# function to check error in any command
func_check_error ()
{
	if [ $1 -ne 0 ]; then
		bash mail_notification.sh alert.template "Logs shipping error" "$2"
	fi
}


# function to check required directories and creating if needed
func_create_directories ()
{		
	if [ ! -d ${BASE_PATH}/logs_consume ]; then
		mkdir ${BASE_PATH}/logs_consume 2>&1 | tee -a log.txt
		func_check_error ${PIPESTATUS[0]} "Error in creating directory logs_consume. Please check!"
	fi

	if [ ! -d ${BASE_PATH}/logs_consume_backup ]; then
		mkdir ${BASE_PATH}/logs_consume_backup 2>&1 | tee -a log.txt
		func_check_error ${PIPESTATUS[0]} "Error in creating directory logs_consume_backup. Please check!"
	fi

	if [ ! -d ${BASE_PATH}/logs_backup ]; then
		mkdir ${BASE_PATH}/logs_backup 2>&1 | tee -a log.txt
		func_check_error ${PIPESTATUS[0]} "Error in creating directory logs_backup. Please check!"
	fi

	if [ ! -d ${BASE_PATH}/logs_backup/logs ]; then
		mkdir ${BASE_PATH}/logs_backup/logs 2>&1 | tee -a log.txt
		func_check_error ${PIPESTATUS[0]} "Error in creating directory logs_backup/logs. Please check!"
	fi 
}

# function to check exit status of sqlcmd and bcp command and report errors

func_check_exit_status ()
{
	if [ $1 -ne 0 ]; then
		sqlcmd -S $analytics_sql_server_ip_address -U $analytics_sql_server_username -P $analytics_sql_server_password -d $analytics_sql_server_database_name -i truncate_tables.sql
		bash mail_notification.sh alert.template "Logs consumption error" "Error occured in `echo $2` command at SQL Server with IP address `echo $analytics_sql_server_ip_address`. Tables are truncated and consumption process is halted so check manually for error"
	fi
}

# function to call sql files using sqlcmd

func_call_sql ()
{
	sql_file=$1
	echo "DECLARE @servername varchar(255) = '$servername';" > query.sql
	cat $sql_file >> query.sql
	sqlcmd -S $analytics_sql_server_ip_address -U $analytics_sql_server_username -P $analytics_sql_server_password -d $analytics_sql_server_database_name -i query.sql > /dev/null 2>&1
	exit_status=`echo $?`
	rm query.sql
	func_check_exit_status $exit_status "sqlcmd"
	echo $exit_status
}


# reading text file in logs folder and then recombining parts

func_recombine ()
{
	for file in `ls ${BASE_PATH}/logs/*.txt`;
	do
		
		total_files=`grep "total_parts*" $file | awk -F'=' '{print $2}'`
		tar_name=`basename $file | sed -e 's/.txt//'`
		files_present=`ls ${BASE_PATH}/logs/$tar_name.split* | wc -l`
		
		if [ $total_files -eq $files_present ]; then

			# recombine all parts
			cat ${BASE_PATH}/logs/$tar_name.split* > ${BASE_PATH}/logs/$tar_name
			rm ${BASE_PATH}/logs/$tar_name.split*
			md5sum=`grep "md5sum*" $file | awk -F'=' '{print $2}'`
			
			md5sum_present=`md5sum ${BASE_PATH}/logs/$tar_name | awk '{ print $1 }'`
			
			if [ $md5sum != $md5sum_present ]; then
				bash mail_notification.sh alert.template "Logs consumption error" "md5sum error in file `echo $tar_name`"
			else
				# removing .txt file having archive information
				rm ${BASE_PATH}/logs/$tar_name.txt
				# file ready to be processed
				# tar file for sending to backup
				cp ${BASE_PATH}/logs/$tar_name ${BASE_PATH}/logs_consume/$tar_name
				mv ${BASE_PATH}/logs/$tar_name ${BASE_PATH}/logs_backup/logs/$tar_name
				# log files to get consumed
				tar -x -C ${BASE_PATH}/logs_consume -f ${BASE_PATH}/logs_consume/$tar_name

				# if archive is extracted then remove archive file
				if [ $? -eq 0 ]; then
					rm ${BASE_PATH}/logs_consume/$tar_name
				fi

			fi
		fi

	done
}

func_consume ()
{
	# initializing bcp_exit_status
	bcp_exit_status_1=0
	bcp_exit_status_2=0
	bcp_exit_status_3=0

	# code for importing data from log files to tables
	
	# checking if sql server is active or not in order to continue consumption
	ping -q -c 1 $analytics_sql_server_ip_address > /dev/null 2>&1

	if [ "$?" = 0 ]; then
					  
		# checking schema and creating if needed
		func_call_sql check_schemas.sql > /dev/null
		
		# creating tables in tmp schema (this will create table at first run of script)
		
		func_call_sql create_tables.sql > /dev/null

		# removing GMT text from log files

		for file in `ls ${BASE_PATH}/logs_consume/raw_*_${servername}_db.log.rotated.*.log`
		do
			sed -i -e 's/GMT//' $file
		done

		# importing clicks files

		for file in `ls ${BASE_PATH}/logs_consume/raw_clicks_*_${servername}_db.log.rotated.*.log`
		do
			bcp [${analytics_sql_server_database_name}].tmp.${servername}_raw_clicks in "${file}" -S $analytics_sql_server_ip_address -U $analytics_sql_server_username -P $analytics_sql_server_password -f raw_clicks.fmt
			temp_bcp_exit_status_1=`echo $?`
			(( bcp_exit_status_1+=temp_bcp_exit_status_1 ))

		done

		# importing impressions files

		for file in `ls ${BASE_PATH}/logs_consume/raw_impressions_*_${servername}_db.log.rotated.*.log`
		do
			bcp [${analytics_sql_server_database_name}].tmp.${servername}_raw_impressions in "${file}" -S $analytics_sql_server_ip_address -U $analytics_sql_server_username -P $analytics_sql_server_password -f raw_impressions.fmt
			temp_bcp_exit_status_2=`echo $?`
			(( bcp_exit_status_2+=temp_bcp_exit_status_2 ))

		done

		# importing requests files

		for file in `ls ${BASE_PATH}/logs_consume/raw_requests_*_${servername}_db.log.rotated.*.log`
		do
			bcp [${analytics_sql_server_database_name}].tmp.${servername}_raw_requests in "${file}" -S $analytics_sql_server_ip_address -U $analytics_sql_server_username -P $analytics_sql_server_password -f raw_requests.fmt
			temp_bcp_exit_status_3=`echo $?`
			(( bcp_exit_status_3+=temp_bcp_exit_status_3 ))
		done

		# # making intermediate clean tables
		# sqlcmd -S 127.0.0.1\\SQLEXPRESS -E -d database -i clean_tables.sql

		# # making transformations to get resultant table
		# sqlcmd -S 127.0.0.1\\SQLEXPRESS -E -d database -i transformation.sql

		# # joining result of this run of script with historical data
		# sqlcmd -S 127.0.0.1\\SQLEXPRESS -E -d database -i join_result.sql

		# # deleting data from all tables used in transformation
		# sqlcmd -S 127.0.0.1\\SQLEXPRESS -E -d database -i truncate_tables.sql


		# checking if all bcp is done succesfully then only perform analytics

		if [ $bcp_exit_status_1 -eq 0 ] && [ $bcp_exit_status_2 -eq 0 ] && [ $bcp_exit_status_3 -eq 0 ]; then
			
			# calling comsumption query part 1
			sql_exit_status_1=`func_call_sql consumption_query_part1.sql`

			# calling consumption query part 2
			sql_exit_status_2=`func_call_sql consumption_query_part2.sql`

			# truncating temporary tables used
			sql_exit_status_3=`func_call_sql truncate_tables.sql`

			# check if all sql queries are run successfully then remove consumption files
			if [ $sql_exit_status_1 -eq 0 ] && [ $sql_exit_status_2 -eq 0 ] && [ $sql_exit_status_3 -eq 0 ]; then
				# move consumed log files to logs_consume_backup
				mv ${BASE_PATH}/logs_consume/raw_*_${servername}_db.log.rotated.*.log ${BASE_PATH}/logs_consume_backup/
			fi 
			

		else
			# report bcp error to server admin and run clean tables sql script
			func_check_exit_status 1 "bcp"
		fi

	else
		# report to admin that sql server is not active
		bash mail_notification.sh alert.template "Logs consumption error" "SQL Server having IP address `echo $analytics_sql_server_ip_address` is not present"
	fi
}


# setting trap for the script
trap func_interrupt_handler SIGINT SIGQUIT SIGTERM

# creating required directories
func_create_directories

# if log files are present then call functions
if [ `ls ${BASE_PATH}/logs/* | head -1` ]; then

	# main script code starts here
	func_recombine

	func_consume

else
	bash mail_notification.sh alert.template "Logs Consumption error" "No new file to be consumed"

fi