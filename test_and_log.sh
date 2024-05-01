#! /bin/bash

# Function to configure script variables
configure_script() {
    echo "*------------------- configuring vars -------------------*"
    # Check if the configuration file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Configuration file '$CONFIG_FILE' not found."
        exit 1
    fi
    # Source the configuration file
    source "$CONFIG_FILE"
}


# Function to create log file
create_log_file() {
    echo "*------------------- create log file -------------------*"
    if ! touch "$LOG_FILE"; then
        echo "Failed to create log file"
        exit 1
    fi
    > "$LOG_FILE"
}

# Back up files at /root
backup_files() {
  echo "*------------------- Back up files at /root -------------------*"
  cp $DATA_DIR/guest.errlog $BACKUP_DIR/guest.errlog_cp
  cp $DATA_DIR/20*.log $BACKUP_DIR/guest.executionlog_cp
  cp $DATA_DIR/guest.conf $BACKUP_DIR/guest.conf_cp
  cp $DATA_DIR/guest.testing_data $BACKUP_DIR/guest.testing_data_cp
}

create_err_json(){
  echo "*------------------- constract the document for elastic upload -------------------*"
  #cd /root/
  touch "$ERR_LOG_JSON"
  echo -e "{\n" > "$ERR_LOG_JSON"
  # count will provide json keys for error lines
  line_count=1

  echo "*------------------- PREPARE ERROR LOG -------------------*"
  # remove json special characters
  sed -i 's|"||g' $ERR_LOG_CP
  sed -i "s|'||g" $ERR_LOG_CP
  sed -i "s|:||g" $ERR_LOG_CP
  # Removes all control chars
  sed -i 's/[\x01-\x1F\x7F]//g' $ERR_LOG_CP
  # remove spaces\tabs in line start
  sed -i -e 's/^[ \t]*//' $ERR_LOG_CP
  # remove problematic control characters
  sed -i -e "s|\r||g" $ERR_LOG_CP
  sed -i -e "s|\t||g" $ERR_LOG_CP
  sed -i -e 's|\b||g' $ERR_LOG_CP
  sed -i -e 's|\r||g' $ERR_LOG_CP
  #sed -i -e 's||g' $ERR_LOG_CP
  sed -i -e 's|\\||g' $ERR_LOG_CP



  today=$(date +"%Y-%m-%dT%TZ")

  # Build error log CSV file.
  moderrlog=""
  while IFS= read -r line
  do
  if [[ ! -z "$line"  ]]
  then
  moderrlog+="[${line}],"
  moderrlog+=$'\n'
  fi
  done < $ERR_LOG_CP

  echo "*------------------- PREPARE Execution LOG -------------------*"
  # remove json special characters
  sed -i 's|"||g' $EXEC_LOG_CP
  sed -i "s|'||g" $EXEC_LOG_CP
  sed -i "s|:||g" $EXEC_LOG_CP
  # Removes all control chars
  sed -i 's/[\x01-\x1F\x7F]//g' $EXEC_LOG_CP
  # remove spaces\tabs in line start
  sed -i -e 's/^[ \t]*//' $EXEC_LOG_CP
  # remove problematic control characters
  sed -i -e "s|\r||g" $EXEC_LOG_CP
  sed -i -e "s|\t||g" $EXEC_LOG_CP
  sed -i -e 's|\b||g' $EXEC_LOG_CP
  sed -i -e 's|\r||g' $EXEC_LOG_CP
  sed -i -e 's|\\||g' $EXEC_LOG_CP
  # Build error log CSF
  modexecutionlog=""
  while IFS= read -r line
  do
  if [[ ! -z "$line"  ]]
  then
  modexecutionlog+="[${line}],"
  modexecutionlog+=$'\n'
  fi
  done < $EXEC_LOG_CP

  echo "*------------------- add conf data to json errlog: -------------------*"
  # Modify OSDescrition in guest.conf so that it wont try to run during source
  sed -i "s/OSDescription/#OSDescription/g" $GUEST_CONF_CP
  sed -i "s/guestDescription/#guestDescription/g" $GUEST_CONF_CP

  ## include the CWM data ##
  source $GUEST_CONF_CP
  source $GUEST_TESTING_DATA_CP

  cat <<EOF >> $ERR_LOG_JSON
    "cwm_domain": "$cwm_domain",
    "test_name": "$test_name",
    "zone": "$zone",
    "name": "$name",
    "cpu": "$cpu",
    "ram": "$ram",
    "managedHosting": "$managedHosting",
    "backup": "$backup",
    "billingCycle": "$billingCycle",
    "disk0size": "$disk0size",
    "vlan0": "$vlan0",
    "mac0": "$mac0",
    "ip0": "$ip0",
    "zoneDescription": "$zoneDescription",
    "url": "$url",
    "OS": "$OS",
    "licensePrice": "$licensePrice",
    "requiredWAN": "$requiredWAN",
    "requiredLAN": "$requiredLAN",
    "date": "$today",
    "tag": "$vm_tag",
    "installer_exit_code": "$installer_exit_code",
    "executionlog": "$modexecutionlog",
    "errlog": "$moderrlog"
EOF
    echo -e "\n}" >> $ERR_LOG_JSON
}

# For systems running csf - allow elastic
# Function to allow elastic in firewall
csf_allow() {
    echo "*------------------- FW stuff -------------------*"
    if systemctl is-active csf &> /dev/null; then
        csf -a "$ELK_SRV_IP"
    fi
}

# Send the data to elastic server
send_msg(){
  echo "*------------------- forward to nginx -------------------*"
  if ! curl -XPOST -H "Host: add.data.to.elk" "$ELK_SRV_NGINX" -d "@$ERR_LOG_JSON" --insecure >> "$LOG_FILE" 2>&1; then
      echo "Failed to send message to nginx"
      exit 1
  fi
}

# Function to clean up temporary files
cleanup() {
    echo "*------------------- Remove temp guest files -------------------*"
    rm -rf "$ERR_LOG_CP" "$EXEC_LOG_CP" "$GUEST_CONF_CP"
}

echo "*------------------- publish to elk -------------------*"
# Check if positional parameters $1 and $2 are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <elk_srv_nginx> <elk_srv_ip>"
    exit 1
fi
ELK_SRV_NGINX="$1"
ELK_SRV_IP="$2"
CONFIG_FILE="./test_and_log.conf"

configure_script
create_log_file
backup_files
create_err_json
csf_allow
send_msg
cleanup
exit 0
