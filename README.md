Steps to run scripts:

	For Source Server side scripts:
	-download all files into a directory
	-open file "config" and fill in required parameters (instructions to fill it is given within the file itself)
	-make a folder name "logs"(in the same diretory where you have downloaded the scripts) and place raw log files into it.
	-run the script named "push_files.sh"
	-NOTE: you will need the files obtained in "logs_backup" folder to run the scripts at Intermediate Server side

	For Intermediate Server side scripts:
	-download all files into a directory
	-open file "config" and fill in required parameters (instructions to fill it is given within the file itself)
	-make a folder name "logs"(in the same diretory where you have downloaded the scripts) and place files present in "logs_backup" folder at Source Server 	 side into it.
	-run the script named "consumption.sh"
	-run the script named "push_files.sh"
	-NOTE: you will need the files obtained in "logs_backup/logs_backup" folder to run the scripts at Destination Server side

	For Destination Server side scripts:
	-download all files into a directory
	-open file "config" and fill in required parameters (instructions to fill it is given within the file itself)
	-make a folder name "logs"(in the same diretory where you have downloaded the scripts) and place files present in "logs_backup/logs_backup" folder at 		 Intermediate Server side into it.
	-run the script named "recombine.sh"
