Shakeel,

Here are some notes on how to run this (but using a .netrc file is more secure):

./cluster_start_stop.sh -h YOURHOST -c c124 -a stop -N admin:YOUR_PASSWORD -t 600 -d

You should change to use a Netrc file:
./cluster_start_stop.sh -h YOURHOST -c c124 -a stop -n YOUR_NETRC_FILE -t 600 -d

Example:
./cluster_start_stop.sh -h node1.my.domain -c c124 -a start -n ~/.netrc -t 600 -d

You need a .netrc file. E.e. vi ~/.netrc

Add something like this where node1.my.domain is the Ambari host, admin is the Ambari admin user and BAD-PASSWD# is the password for admin :

machine node1.my.domain login admin password BAD-PASSWD#

Important:
chmod 700 ~/.netrc

Later we will enable SSL/TLS so you will add -p 8443 and -s arguments. I have not tested this yet though.

Example:
./cluster_start_stop.sh -h node1.my.domain -p 8443 -s -c c124 -a start -n ~/.netrc -t 600 -d

If you want the password in a vault or something, just wrap the script and generate a .netrc file on the fly and remove it when it is completed.

Jim

