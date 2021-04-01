echo $1
# REM echo '{"hello":"'$(1)'"}'

 iothubtoken=$(az iot hub generate-sas-token -n $1 | jq .sas | tr -d \")


JSON_STRING=$( jq -n \
                  --arg helloarg "$iothubtoken" \
                  '{hello: $helloarg}' )

echo $JSON_STRING

