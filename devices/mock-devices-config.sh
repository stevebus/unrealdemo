file=$1
iothub_name=$2

for row in $(cat $file | jq .devices[].configuration | jq 'select(._kind == "hub")' | jq -c '{deviceId: .deviceId, connstr: .connectionString}');
do
    echo $row
    deviceId=$(echo $row | jq .deviceId -r)
    connstr=$(echo $row | jq .connstr -r)
#    echo $deviceId
#    echo $connstr

    newconnstr=$(az iot hub device-identity connection-string show -n $iothub_name -d $deviceId -o tsv)
    if [ -z "$newconnstr" ]
    then
        echo "device $deviceId does not exist, creating... "
        resp=$(az iot hub device-identity create -n $iothub_name -d $deviceId --query "authentication.symmetricKey.primaryKey" -o tsv)
        newconnstr="HostName=$iothub_name.azure-devices.net;DeviceId=$deviceId;SharedAccessKey=$resp"
    fi

    echo $newconnstr
    sed -i s~"$connstr"~"$newconnstr"~ $file

done