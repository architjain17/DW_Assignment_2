#! /bin/bash

# grabbing email id(s) from config file
server_admin_email_id=`grep "server_admin_email_id*" config | awk -F'=' '{print $2}'`
servername=`grep "servername*" config | awk -F'=' '{print $2}'`

# grabbing template name to be used which is passed as a parameter to the script

template=$1

if [ $template = "success.template" ]; then
	
	sed -e '/{successfiles}/r run_details_ship_success.txt' -e 's/{successfiles}//' success.template > email_body

	rm run_details_ship_success.txt

elif [ $template = "failure.template" ]; then
	
	sed -e '/{failedfiles}/r run_details_ship_failure.txt' -e 's/{failedfiles}//' failure.template > email_body

	rm run_details_ship_failure.txt

elif [ $template = "success_failure.template" ]; then
	
	sed -e '/{successfiles}/r run_details_ship_success.txt' -e 's/{successfiles}//' success_failure.template > email_body
	sed -i -e '/{failedfiles}/r run_details_ship_failure.txt' -e 's/{failedfiles}//' email_body	

	rm run_details_ship_success.txt
	rm run_details_ship_failure.txt

elif [ $template = "alert.template" ]; then

	sed -e "s/{alertsubject}/[Servername:$servername] $2/" alert.template > email_body
	sed -i -e "s/{alertmessage}/$3/" email_body

fi

# command to get own IP address
source_server_ip=`hostname -I | awk '{print $1}'`

# grabbing intermediate server IP address from config file
intermediate_server_ip=`grep "intermediate_server_ip*" config | awk -F'=' '{print $2}'`

# placing source and intermediate server IP addresses in email_body

sed -i -e "s/{source_server_ip}/$source_server_ip/" -e "s/{intermediate_server_ip}/$intermediate_server_ip/" email_body

# sending mail
msmtp --from=default -t $server_admin_email_id < email_body

# removing temporary file
rm email_body
