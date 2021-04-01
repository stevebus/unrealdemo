
iothub_name=$1
primaryKey='M4M04OgpQHC9RDfOUXwBwXvnFNWvcA/3MweXLHwhjBo='
secondaryKey='M4M04OgpQHC9RDfOUXwBwXvnFNWvcA/3MweXLHwhjBo='

echo "iot hub name: ${iothub_name}"

echo 'installing azure cli extension'

# az extension add --name azure-iot -y

iothubtoken=$(az iot hub generate-sas-token -n $iothub_name | jq .sas | tr -d \")

echo "iot hub token: ${iothubtoken}"

for dev in {121..125}
do
    deviceId="device${dev}"

#    data='{"deviceId":"'"$deviceId"'", "authentication":{"symmetricKey":{"primaryKey":"M4M04OgpQHC9RDfOUXwBwXvnFNWvcA/3MweXLHwhjBo=","secondaryKey":"M4M04OgpQHC9RDfOUXwBwXvnFNWvcA/3MweXLHwhjBo="}},"status":"enabled"}'
#    echo $data
    curl -L -i -g -X PUT -H 'Content-Type: application/json' -H 'Content-Encoding:  utf-8' -H "Authorization: $iothubtoken" -d '{"deviceId":"'"$deviceId"'", "authentication":{"symmetricKey":{"primaryKey":"'"$primaryKey"'","secondaryKey":"'"$secondaryKey"'"}},"status":"enabled"}' "https://$iothub_name.azure-devices.net/devices/$deviceId?api-version=2020-05-31-preview"
#    curl -L -g -X PUT -H 'Content-Type: application/json' -H 'Content-Encoding:  utf-8' -H "Authorization: $iothubtoken" -d $data "https://$iothub_name.azure-devices.net/devices/$deviceId?api-version=2020-05-31-preview"
done

JSON_STRING=$( jq -n \
                  --arg hubname "$iothub_name" \
                  --arg hubtoken "$iothubtoken" \
                  '{hubname: $hubname, hubtoken: $hubtoken}' )

echo $JSON_STRING
