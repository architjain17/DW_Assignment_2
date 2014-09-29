#! /bin/bash

# grabbing email id(s) from config file
server_admin_email_id=`grep "server_admin_email_id*" config | awk -F'=' '{print $2}'`

sed -e "s/{alertsubject}/[Servername:$servername] $2/" alert.template > email_body
sed -i -e "s/{alertmessage}/$3/" email_body

# command to get own IP address
source_server_ip=`hostname -I | awk '{print $1}'`

# placing source server IP addresses in email_body

sed -i -e "s/{source_server_ip}/$source_server_ip/" email_body

# sending mail
msmtp --from=default -t $server_admin_email_id < email_body

# removing temporary file
rm email_body
