CURL_OPTS="-s"
######## FUNCTIONS

function usage() {
  echo "$1"
  echo "usage: `basename $0` <options>"
  echo "  This script will start or stop an HDP cluster via the Ambari REST API"
  echo "    -h ambari_host"
  echo "    -p ambari_port    - optional. Default is 8080"
  echo "    -s                - use https"
  echo "    -c clustername"
  echo "    -a action         - start|stop"
  echo "    -n netrc_file     - File with creds in this format where HOST, USER and MYPW are values."
  echo "                        machine HOST login USER password MYPW"
  echo "                        example: 'machine YOURHOST login YOURUSER password YOURPW'"
  echo "                        IMPORTANT - protect the file with chmod 700."
  echo "                        The script could be modified for kerberos authN"
  echo "    -N user_pw        - username:password \(e.g. admin:admin\) for login instead of netrc file"
  echo "                        This is less secure than a using netrc or kerberos."
  echo "    -t timeout        - approx seconds to wait for action to complete [default=1200, 20 mins]"
  echo "    -v                - verbose"
  echo "    -d                - print debug messages"
  echo "EXAMPLES"
  echo "    `basename $0` -h ambari.example.com -c cluster1 -a start -v -d -n ~/.netrc"
  echo "    `basename $0` -h ambari.example.com -c cluster1 -a start -v -d -N admin:\$MYPW"

  exit 254

}



function exit_error() {
   msg=$1
   echo -e "$msg"
   exit 255
}


function debug() {
     echo "   DEBUG: $1" >&2
}


function startCluster() {

 retval=$(curl $CURL_OPTS -k -f $CREDS -i -H 'X-Requested-By: ambari' -X PUT \
  -d '{"RequestInfo":{"context":"_PARSE_.START.ALL_SERVICES","operation_level":{"level":"CLUSTER","cluster_name":"HDP"}},"Body":{"ServiceInfo":{"state":"STARTED"}}}' $PROTO://$AMB_HOST/api/v1/clusters/$CLUSTER/services?)
  ecode=$?

  #[ $? -ne 0 ] && exit_error "ERROR: start command failed"
  [ $ecode -ne 0 ] && exit_error "ERROR: start command failed\n\nCREDS=$CREDS\n\n$retval"

}


function startClusterWait() {

  startCluster

  #url=$(startCluster |grep "$PROTO://$AMB_HOST" |sed 's#".*\($PROTO:.*\)".*#\1#')
  url=$(echo -n "$retval" |egrep "href.*$PROTO://$AMB_HOST" | awk -F',| ' '{print $5}' | sed -e 's/"//g')

  [[ -z $url ]] && exit_error "Curl command failed when starting. It did not return results"

  [ $VERBOSE -ne 0 ] && echo "Status URL: $url"

  waitForStatus "$url" COMPLETED
}


function stopCluster() {

  retval=$(curl $CURL_OPTS -k -f $CREDS -i -H 'X-Requested-By: ambari' -X PUT \
  -d '{"RequestInfo":{"context":"_PARSE_.STOP.ALL_SERVICES","operation_level":{"level":"CLUSTER","cluster_name":"HDP"}},"Body":{"ServiceInfo":{"state":"INSTALLED"}}}' $PROTO://$AMB_HOST/api/v1/clusters/$CLUSTER/services)
  ecode=$?

  [ $ecode -ne 0 ] && exit_error "ERROR: stop command failed\n\nCREDS=$CREDS\n\n$retval"
}

function stopClusterWait() {

  stopCluster  #this will return culr results in "$retval"

  [ $VERBOSE -ne 0 ] && echo -e "$retval\n\n"

  url=$(echo -n "$retval" |egrep "href.*$PROTO://$AMB_HOST" | awk -F',| ' '{print $5}' | sed -e 's/"//g')


  [[ -z $url ]] && exit_error "Curl command failed when stopping. It did not return results"
  [ $VERBOSE -ne 0 ] && echo "Status URL: $url"

  waitForStatus "$url" COMPLETED
}


function waitForStatus() {
  # Use the URL to track and wait for the expected status
  url=$1
  expected_status=$2 #some values can be: PENDING, IN_PROGRESS, COMPLETED, FAILED, ABORTED

  [ $DEBUG -ne 0 ] && debug "Waiting for status: $expected_status"

  sleep_time=3
  max_sleeps=$(($TIMEOUT/${sleep_time}))  #Calculate how long to wait

  start_time=`date "+%s"`

  finished=0
  while [ $finished -ne 1 ]; do
    str=$(curl $CURL_OPTS -k -f $CREDS $url)
    str=$(echo -e "$str" |grep "request_status")

    elapsed=$((`date "+%s"` - start_time))

    [ $DEBUG -ne 0 ] && debug "url: $url"
    [ $DEBUG -ne 0 ] && debug "-- Status: $str [elapsed $elapsed/$TIMEOUT secs]"


    if [[ $str == *"$expected_status"* ]]
    then
      finished=1
    elif [ $elapsed -gt $TIMEOUT ];then
      exit_error "ERROR: Timeout waiting on status. Status is: $str\nMonitoring URL: $url"
    elif [[ $str == *"ABORTED"* ]] || [[ $str == *"FAILED"* ]]; then
      exit_error "ERROR: Failed based on status: $str"
    else
      sleep $sleep_time
    fi
  done

}




########## MAIN ##########

# set defaults
PROTO=http
PORT_ARG=8080
TIMEOUT=1200  #20 minutes
VERBOSE=0
DEBUG=0

# commandline args
while getopts "sh:p:c:a:n:N:t:m:vd" opt; do
  [ $DEBUG -ne 0 ] && debug "opt=$OPT, OPTIND=$OPTIND"
  case "$opt" in
    s) PROTO=HTTPS;;
    h) HOST_ARG=$OPTARG;;
    p) PORT_ARG=$OPTARG;;
    c) CLUSTER=$OPTARG;;
    a) ACTION=$OPTARG;;
    n) CREDS="--netrc-file $OPTARG";;
    N) CREDS="-u $OPTARG";;
    t) TIMEOUT=$OPTARG;;
    v) VERBOSE=1;;
    d) DEBUG=1;;
    *) usage "Invalid option: $opt $OPTARG.";;
  esac
done


# validate args
[[ -z $HOST_ARG ]] && usage "Missing -h arg"
[[ -z $PORT_ARG ]] && usage "Missing -p arg"
[[ -z $CLUSTER ]] && usage "Missing -c arg"
[[ -z $CREDS ]] && usage "Missing -n or -N arg"
[[ -z $ACTION ]] && usage "Missing -a arg"
[[ $ACTION != "start" ]] && [[ $ACTION != "stop" ]] && usage "Invalid action: $ACTION "

AMB_HOST=${HOST_ARG}:${PORT_ARG}


# let's do it

case $ACTION in
   start)
      ## START CLUSTER
      [ $DEBUG -ne 0 ] && debug "starting cluster $CLUSTER"
      startClusterWait;;
   stop)
      [ $DEBUG -ne 0 ] && debug "stopping cluster $CLUSTER"
      stopClusterWait;;
esac

