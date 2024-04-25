
echo "*------------------- publish to elk -------------------*"

echo "*------------------- define elk variables -------------------*"
# Check if positional parameters $1 and $2 are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <elk_srv_nginx> <elk_srv_ip>"
fi
elk_srv_nginx="$1"
elk_srv_ip="$2"

echo "*------------------- create log file -------------------*"
# Define log for that script
touch /root/new_add_elk.log
logfile="/root/new_add_elk.log"
> $logfile

echo "*------------------- Back up files at /root -------------------*"
## Back up files at /root
cp /root/guest.errlog /root/guest.errlog_cp
cp /root/20*.log /root/guest.executionlog_cp
cp /root/guest.conf /root/guest.conf_cp

echo "*------------------- define temp guest files vars -------------------*"
## VARS ##
errlog_cp=/root/guest.errlog_cp  #copy of guest.errlog
execlog_cp=/root/guest.executionlog_cp #copy of 2023-XX-XX.log
guestconf_cp=/root/guest.conf_cp #copy of guest.conf


echo "*------------------- constract the document fo elastic upload -------------------*"
cd /root/
touch guest.errlog.json
echo -e "{\n" > ./guest.errlog.json
# count will provide json keys for error lines
line_count=1


echo "*------------------- PREPARE ERROR LOG -------------------*"
# Remove special characters from guest.errlog - make sure that guest.errlog.jsc
# remove json special characters
sed -i 's|"||g' $errlog_cp
sed -i "s|'||g" $errlog_cp
sed -i "s|:||g" $errlog_cp
# Removes all control chars
sed -i 's/[\x01-\x1F\x7F]//g' $errlog_cp
# remove spaces\tabs in line start
sed -i -e 's/^[ \t]*//' $errlog_cp
# remove problematic control characters
sed -i -e "s|\r||g" $errlog_cp
sed -i -e "s|\t||g" $errlog_cp
sed -i -e 's|\b||g' $errlog_cp
sed -i -e 's|\r||g' $errlog_cp
#sed -i -e 's||g' $errlog_cp
sed -i -e 's|\\||g' $errlog_cp

# Modify OSDescrition in guest.conf so that it wont try to run during source
sed -i "s/OSDescription/#OSDescription/g" $guestconf_cp
sed -i "s/guestDescription/#guestDescription/g" $guestconf_cp

today=$(date +"%Y-%m-%dT%TZ")
vm_tag="container managment system"

# Build error log CSF
moderrlog=""
while IFS= read -r line
do
if [[ ! -z "$line"  ]]
then
moderrlog+="[${line}],"
moderrlog+=$'\n'
fi
done < $errlog_cp
#########################################

echo "*------------------- PREPARE Execution LOG -------------------*"
# remove json special characters
sed -i 's|"||g' $execlog_cp
sed -i "s|'||g" $execlog_cp
sed -i "s|:||g" $execlog_cp
# Removes all control chars
sed -i 's/[\x01-\x1F\x7F]//g' $execlog_cp
# remove spaces\tabs in line start
sed -i -e 's/^[ \t]*//' $execlog_cp
# remove problematic control characters
sed -i -e "s|\r||g" $execlog_cp
sed -i -e "s|\t||g" $execlog_cp
sed -i -e 's|\b||g' $execlog_cp
sed -i -e 's|\r||g' $execlog_cp
#sed -i -e 's||g' $execlog_cp
sed -i -e 's|\\||g' $execlog_cp
# Build error log CSF
modexecutionlog=""
while IFS= read -r line
do
if [[ ! -z "$line"  ]]
then
modexecutionlog+="[${line}],"
modexecutionlog+=$'\n'
fi
done < $execlog_cp
#####################################


echo "*------------------- add conf data to json errlog: -------------------*"
#adding conf data to Document:
## include the CWM data ##
source ./guest.conf_cp
cat <<EOF >> ./guest.errlog.json
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

echo -e "\n}" >> ./guest.errlog.json

echo "*------------------- FW stuff -------------------*"
# For systems running csf - allow elastic ip:
systemctl is-active csf
if [[ $? == 0 ]]
then
csf -a ${elk_srv_ip}
fi

echo "*------------------- forward to nginx: -------------------*"
## POST RQUEST ##
curl -XPOST -H "Host: add.data.to.elk" "${elk_srv_nginx}" -d '@guest.errlog.json' --insecure >> $logfile 2>&1


echo "*------------------- Remove temp guest files -------------------*"
rm -rf $errlog_cp
rm -rf $execlog_cp
rm -rf $guestconf_cp

