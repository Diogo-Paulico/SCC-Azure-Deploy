#!/bin/bash
source configs.azure

echo "This will take some time... You do not need to wait for the process to finish, you can close the shell in a few seconds!"
az resource delete --ids $(az group show --name $RESOURCE_GROUP  | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
clear
echo "Resources Deleted!"
