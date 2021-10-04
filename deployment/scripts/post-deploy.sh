
adtname=$1
rgname=$2
egname=$3

# install/update azure iot az cli extension
az extension add --name azure-iot -y

# # create ADT endpoint and route for signalR integration
# eptest=$(az dt endpoint show --dt-name $adtname --en "$egname-ep" 2>null)
# if [ -z $eptest ];
# then
#   az dt endpoint create eventgrid --dt-name $adtname --eventgrid-resource-group $rgname --eventgrid-topic $egname --endpoint-name "$egname-ep"
# else
#   echo 'endpoint exists, skipping creation'
# fi

rttest=$(az dt route show --dt-name $adtname --rn "$egname-rt" 2> null)
if [ -z $rttest];
then
  az dt route create --dt-name $adtname --endpoint-name "$egname-ep" --route-name "$egname-rt"
else
  echo 'route exists, skipping creation'
fi