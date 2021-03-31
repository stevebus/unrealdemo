
iothub_name=$1

echo 'installing azure cli extension'

# az extension add --name azure-iot -y

iothubtoken=$(az iot hub generate-sas-token -n $iothub_name | jq .sas | tr -d \")

JSON_STRING=$( jq -n \
                  --arg helloarg "$iothubtoken" \
                  '{hello: $helloarg}' )

echo $JSON_STRING
