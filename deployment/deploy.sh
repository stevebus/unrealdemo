
## probably need to do an az login

userObject=$(az ad signed-in-user show --query 'objectId' -o tsv)

if [ -z "$userObject" ]; 
then
    echo 'User not logged in.  Please run "az login" from the azure CLI, log in with an account that has azure subscription admin rights, and run the script again'
    exit 0
fi

az deployment group create -g sdbarmtest -f ./azuredeploy.bicep --parameters projectName='unrealpoc' userId=$userObject
