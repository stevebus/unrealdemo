
adtname=$1
rgname=$2
egname=$3

# install/update azure iot az cli extension
az extension add --name azure-iot -y

rttest=$(az dt route show --dt-name $adtname --rn "$egname-rt" 2> null)
if [ -z $rttest];
then
  az dt route create --dt-name $adtname --endpoint-name "$egname-ep" --route-name "$egname-rt"
else
  echo 'route exists, skipping creation'
fi