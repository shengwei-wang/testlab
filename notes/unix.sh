*****************************************************************************************
-- UNIX shell
*****************************************************************************************
************ .bashrc ************
#########################################################
# Alias
#########################################################
alias ..="cd .."
alias ...="cd ..\.."
alias ll="ls -lrpthe"
alias ssu="sudo su - pyph0app"
alias t2="ssh shenwang@usvw02t2"
alias t1="ssh shenwang@usvw02t1"
alias d1="ssh shenwang@usvw02d1"



************ ping ************
## on Solaris Unix servers, ping command is here
$ /usr/sbin/ping -s aset012 56 3

************ use ls result in cp comand ************
ls | grep 239414483 && cp `ls | grep 23941448 | tail -1` /users/shenwang/RATS_Deal_Fix/RATS_bin_files
ls | grep 239414483 && cp `ls | grep 23941448` /users/shenwang/RATS_Deal_Fix/RATS_bin_files


************ scp ************
## https://blogs.oracle.com/jkini/entry/how_to_scp_scp_and

## generate keys
$ ssh-keygen -t rsa

## do scp
$ scp shenwang@usvw27p2:/app/guardian/1035/servers/g3rats-N2/logs/g3rats-N2.out /users/shenwang/RATS_logs/check/g3rats-N2.out

## do ssh commands
$ ssh shenwang@usvw02t1 ls

## guardian properties file sudo copy
$ cp /users/shenwang/JIRA1196/guardian.properties /tmp/guardian.properties
$ chmod 755 /tmp/guardian.properties
$ sudo -u guardian cp /tmp/guardian.properties /app/guardian/1035/opt/config/guardian.properties

************ ln ************
# create a soft link to a dir
$ ln -s /pathToLink linkname
$ ln -s /home/pbjenkin/artifacts pb_artifacts

************ mount ************
# to list mounted dirs
$ mount

************ quota ************
# Displays disk usage and limits for a user of group.
$ quota -s

************ du ************
# du shows how much space one ore more files or directories is using.
$ du -hs /user/mmarket

# disk usage (for current dir). -h is for human readable. -k in kbytes.
$ df -h .
$ df -k .

************ ls ************
# Sort by file size. Use the -r option of sort to list big->small or small->big
$ ls -l | grep ^- | sort -nr -k 5
$ ls -l | grep ^- | sort -n -k 5
$ ls -l | awk '{print $5 " " $9}' |sort -nr

# get file timestamp
$ ls -E
$ ls -E | awk '{print $6}' | grep -v ^$  -----> the yyyy-mm-dd
$ ls -E | awk '{print $7}' | grep -v ^$  -----> the hh:mm:ss
$ ls -E | awk '{print $9}' | grep -v ^$  -----> the filename
(grep -v ^$: get rid of empty lines)
Unix Time stamp tutoril
http://www.unixtutorial.org/2008/04/atime-ctime-mtime-in-unix-filesystems/

# Show the mtime (modify time)
$ ls -l

# Show the atime (access time)
$ ls -lu

# Show the ctime (change time)
$ ls -lc


********** if condition **********
## To test file not exist script:
if [ ! -f $nonExistingFilename ]
then
	echo file not exist
fi

## To test file exist script:
if [ -f $existingFilename ]
then
	echo file exist
fi

## To test if var is empty
if [ -z "$nexus_username" ]
then
	echo $nexus_username is empty
fi

Note: how to use exclamation mark to negate




********** find ************
# delete files by find commands
$ find . -mtime +60 -type f -exec rm {} \;
$ find ./ -name "filenames" -mtime +60 -exec rm {} \;

-type
b - block special file
c - character  special  file
d - directory
D - door
f - plain file
l - symbolic link
p - fifo (named pipe)
s - socket

# clear error dir, keep 2 weeks' files
$ find /users/mmarket/error -mtime +14 -type f -exec rm {} \;


********** tar ************
# Creating a tar gzipped archive using option cvzf
$ tar cvzf archive_name.tar.gz dirname/
c – create a new archive
v – verbosely list files which are processed
x - eXtract, this indicated an extraction c = create to create )
f – following is the archive file name
z – filter the archive through gzip
(http://www.thegeekstuff.com/2010/04/unix-tar-command-examples/)

******** touch **********
$ touch -t 201204251000.30 filename

-t time format: [[CC]YY]MMDDhhmm[.SS] 

MM       The month of the year [01-12].
DD       The day of the month [01-31].
hh       The hour of the day [00-23].
mm       The minute of the hour [00-59].
CC       The first two digits of the year.
YY       The second two digits of the year.
SS       The second of the minute [00-61].

************** ps & kill ****************
$ ps -ef | grep shenwang
$ ps -fu shenwang

# About ps (http://www.cyberciti.biz/tips/top-linux-monitoring-tools.html)

# About kill command (http://www.cyberciti.biz/faq/unix-kill-command-examples/)
$ kill -9 PID


********** grep *************
$ grep -v "^(return status =.*)"

-v invert checking
-n print the line number
-c return the count
-i ignore cases

# recursive grep
find ./ -type f | xargs grep "precompile"
find ./ -name "*.sh" | xargs grep "precompile"

********** sort *************
# Show only unique lines, no duplicate
$ sort -u


********** egrep *************
$ egrep -c -i '(Level|Msg)' filename


********** telnet ************
# direct standard output and error to /dev/null

#!/bin/sh
telnet usvw27t1 8005 >/dev/null 2>&1 << MSG
  type
  type quit
MSG
echo $?


********** sed **************
# do not delete lines matching regex pattern:
$ sed "/USD/!d"

# delete lines matching regex pattern:
$ sed "/USD/d"

# Replace the PATTERN to be xxx in the last line of the file
$ sed '$s/PATTERN/xxx/'

# Insert a line
$ sed '1 i\
insert this line test' tt.txt > t1.txt

********** netstat **************
# check ip address
$ netstat -in
$ ifconfig -a

********** chmod **************
# Recursively chmod only directories
$ find . -type d -exec chmod 755 {} \;

# Similarly, recursively set the execute bit on every directory
$ chmod -R 755 *

# Recursively chmod only files
$ find . -type f -exec chmod 644 {} \;

# Recursively chmod only PHP files (with extension .php)
$ find . -type f -name '*.php' -exec chmod 644 {} \;

********** id *************
$ id -a username
(to list user id, group id)


********** wget *************
/usr/sfw/bin/wget -h
/usr/sfw/bin/wget --help


/usr/sfw/bin/wget "http://nexus.oak.fg.rbc.com/service/local/artifact/maven/content?r=RBCCM-Snapshots&g=com.rbc.rbccm.zmi0&a=pbadmin2&v=LATEST&p=war" -nv --content-disposition --user=P2TWThtb --password=mVboyrioqDcwYAjQA3j1HmhibkxNrbulZauSMzszFa1n -O pbadmin2.war

/usr/sfw/bin/wget "http://nexus.oak.fg.rbc.com/service/local/artifact/maven/resolve?r=RBCCM-Releases&g=com.rbc.rbccm.zmi0&a=pbadmin2&v=LATEST&p=war" --user=P2TWThtb --password=mVboyrioqDcwYAjQA3j1HmhibkxNrbulZauSMzszFa1n -O foo.txt

********** uname (display system OS info) ***********
$ uname -a
SunOS usvmmgnd1 5.10 Generic_147440-05 sun4u sparc SUNW,SPARC-Enterprise


********** dos2unix / unix2dos ***********
$ dos2unix -437 filename filename

Ref:
http://www.linuxmisc.com/3-solaris/8cbabd2eea8908bf.htm
Synopsis: *dos2unix* dos2unix and unix2dos want /dev/kbd 
Description: 
 Both dos2unix and unix2dos print out: 
 could not open /dev/kbd to get keyboard type US keyboard assumed 
 could not get keyboard type US keyboard assumed 
This is a problem because: 
1. There is no /dev/kbd. 
2. Even if there was a /dev/kbd, these programs are trying to 
   do the keyboard ioctl KIOCLAYOUT that returns the nationality of the 
   keyboard.  Under x86 the I don't think that the keyboard ioctl 
   exists, and the keyboards do not have unique gettable numbers that 
   are the nationality.  Some other scheme would be necessary. 
Work around: 
 Ignore the message, or use the intuitive -437 flag. 
Integrated in releases: 
 Duplicate of: 1148242 

********** check printer status *************
$ lpstat -t
$ lpstat -a

# Check print queue, -Pprintername
$ lpq -Pqs5212-041

# Removing print jobs
$ lprm -Pqs5212-041

# Print a file
$ lpr -Pqs5212-041 filename

********** multiline comment ************
1st way:
starts with a colon and a space and a opening apostrophe, the colon has to be first letter
ends with a closing apostrophe
escape char: apostrophe

: '
Comment line 1
Comment line 2
escape ''
'

2nd way, using label:
<<COMMENT
	Comment line 1
	Comment line 2
	blah...
COMMENT

********** combined usage ************
## Go through each line of the param file, ignore lines start with #
cat ${PARAM_FILE} | sed -e 's/^#.*//g'
