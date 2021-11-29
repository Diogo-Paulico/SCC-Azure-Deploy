#!/bin/bash

source configs.azure


generate_sql_cosmos(){
printf "{
    \"\$schema\": \"https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#\",
    \"contentVersion\": \"1.0.0.0\",
    \"variables\": {},
    \"resources\": [
        {
            \"type\": \"Microsoft.DocumentDB/databaseAccounts\",
            \"apiVersion\": \"2021-07-01-preview\",
            \"name\": \"$COSMOS_DB_ACCOUNT_NAME\",
            \"location\": \"West Europe\",
            \"tags\": {
                \"defaultExperience\": \"Core (SQL)\",
                \"hidden-cosmos-mmspecial\": \"\"
            },
            \"kind\": \"GlobalDocumentDB\",
            \"identity\": {
                \"type\": \"None\"
            },
            \"properties\": {
                \"publicNetworkAccess\": \"Enabled\",
                \"enableAutomaticFailover\": false,
                \"enableMultipleWriteLocations\": false,
                \"isVirtualNetworkFilterEnabled\": false,
                \"virtualNetworkRules\": [],
                \"disableKeyBasedMetadataWriteAccess\": false,
                \"enableFreeTier\": true,
                \"enableAnalyticalStorage\": false,
                \"analyticalStorageConfiguration\": {
                    \"schemaType\": \"WellDefined\"
                },
                \"databaseAccountOfferType\": \"Standard\",
                \"networkAclBypass\": \"None\",
                \"disableLocalAuth\": false,
                \"consistencyPolicy\": {
                    \"defaultConsistencyLevel\": \"Session\",
                    \"maxIntervalInSeconds\": 5,
                    \"maxStalenessPrefix\": 100
                },
                \"locations\": [
                    {
                        \"locationName\": \"West Europe\",
                        \"failoverPriority\": 0,
                        \"isZoneRedundant\": false
                    }
                ],
                \"cors\": [],
                \"capabilities\": [],
                \"ipRules\": [],
                \"backupPolicy\": {
                    \"type\": \"Periodic\",
                    \"periodicModeProperties\": {
                        \"backupIntervalInMinutes\": 240,
                        \"backupRetentionIntervalInHours\": 8,
                        \"backupStorageRedundancy\": \"Local\"
                    }
                },
                \"networkAclBypassResourceIds\": [],
                \"diagnosticLogSettings\": {
                    \"enableFullTextQuery\": \"None\"
                }
            }
        }
    ]
}" > depl.json
}

generate_mongo_cosmos(){
printf "{
    \"\$schema\": \"https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#\",
    \"contentVersion\": \"1.0.0.0\",
    \"variables\": {},
    \"resources\": [
        {
            \"type\": \"Microsoft.DocumentDB/databaseAccounts\",
            \"apiVersion\": \"2021-07-01-preview\",
            \"name\": \"$COSMOS_DB_ACCOUNT_NAME\",
            \"location\": \"West Europe\",
            \"kind\": \"MongoDB\",
            \"identity\": {
                \"type\": \"None\"
            },
            \"properties\": {
                \"publicNetworkAccess\": \"Enabled\",
                \"enableAutomaticFailover\": false,
                \"enableMultipleWriteLocations\": false,
                \"isVirtualNetworkFilterEnabled\": false,
                \"virtualNetworkRules\": [],
                \"disableKeyBasedMetadataWriteAccess\": false,
                \"enableFreeTier\": true,
                \"enableAnalyticalStorage\": false,
                \"analyticalStorageConfiguration\": {
                    \"schemaType\": \"FullFidelity\"
                },
                \"databaseAccountOfferType\": \"Standard\",
                \"networkAclBypass\": \"None\",
                \"disableLocalAuth\": false,
                \"consistencyPolicy\": {
                    \"defaultConsistencyLevel\": \"Session\",
                    \"maxIntervalInSeconds\": 5,
                    \"maxStalenessPrefix\": 100
                },
                \"apiProperties\": {
                    \"serverVersion\": \"4.0\"
                },
                \"locations\": [
                    {
                        \"locationName\": \"West Europe\",
                        \"failoverPriority\": 0,
                        \"isZoneRedundant\": false
                    }
                ],
                \"cors\": [],
                \"capabilities\": [
                    {
                        \"name\": \"EnableMongo\"
                    }
                ],
                \"ipRules\": [],
                \"backupPolicy\": {
                    \"type\": \"Periodic\",
                    \"periodicModeProperties\": {
                        \"backupIntervalInMinutes\": 240,
                        \"backupRetentionIntervalInHours\": 8,
                        \"backupStorageRedundancy\": \"Local\"
                    }
                },
                \"networkAclBypassResourceIds\": [],
                \"diagnosticLogSettings\": {
                    \"enableFullTextQuery\": \"None\"
                }
            }
        }
    ]
}" > depl.json
}

sql_cosmos_depl(){
    generate_sql_cosmos
	az group deployment create -g $RESOURCE_GROUP --template-file depl.json
	az cosmosdb sql database create --account-name $COSMOS_DB_ACCOUNT_NAME --name $DATABASE_NAME --resource-group $RESOURCE_GROUP --throughput 400
    az cosmosdb sql container create --account-name $COSMOS_DB_ACCOUNT_NAME --database-name $DATABASE_NAME --name $CO_NAME --partition-key-path "/id" --resource-group $RESOURCE_GROUP
}

mongo_cosmos_depl(){
    generate_mongo_cosmos
	az group deployment create -g $RESOURCE_GROUP --template-file depl.json
   	az cosmosdb mongodb database create --account-name $COSMOS_DB_ACCOUNT_NAME --name $DATABASE_NAME --resource-group $RESOURCE_GROUP --throughput 400
    az cosmosdb mongodb collection create --account-name $COSMOS_DB_ACCOUNT_NAME --database-name $DATABASE_NAME --name $CO_NAME --resource-group $RESOURCE_GROUP
}

blob_deploy(){

    az storage account create -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP -l westeurope --sku Standard_LRS

    #Set container soft-delete to false
    az storage account blob-service-properties update --enable-container-delete-retention false --account-name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP

    #Set blob soft-delete to false
    az storage account blob-service-properties update --account-name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --enable-delete-retention false

    #Set shared file retention to disabled
    az storage account file-service-properties update --account-name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --enable-delete-retention false

    #Create "images" container
    az storage container create -n $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --public-access blob

    az functionapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP --settings "$STORAGE_ACCOUNT_CONNECTION_STRING_VAR_NAME=$(az storage account show-connection-string -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME | python3 -c "import sys, json; print(json.load(sys.stdin)['connectionString'])")"
}

blob_replica_deploy(){

    az storage account create -n $STORAGE_ACCOUNT_REPLICA_NAME -g $RESOURCE_GROUP -l northeurope --sku Standard_LRS

    #Set container soft-delete to false
    az storage account blob-service-properties update --enable-container-delete-retention false --account-name $STORAGE_ACCOUNT_REPLICA_NAME --resource-group $RESOURCE_GROUP

    #Set blob soft-delete to false
    az storage account blob-service-properties update --account-name $STORAGE_ACCOUNT_REPLICA_NAME --resource-group $RESOURCE_GROUP --enable-delete-retention false

    #Set shared file retention to disabled
    az storage account file-service-properties update --account-name $STORAGE_ACCOUNT_REPLICA_NAME --resource-group $RESOURCE_GROUP --enable-delete-retention false

    #Create "images" container
    az storage container create -n $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_REPLICA_NAME --public-access blob

}

db_deploy(){
    az functionapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP --settings "$DB_NAME_VAR_NAME=$DATABASE_NAME"
    if [ $DATABASE_TYPE = "SQL" ]; then
        sql_cosmos_depl
        az functionapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP --settings "$DB_KEY_VAR_NAME=$(az cosmosdb keys list --name $COSMOS_DB_ACCOUNT_NAME --resource-group $RESOURCE_GROUP | python3 -c "import sys, json; print(json.load(sys.stdin)['primaryMasterKey'])")"
        az functionapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP --settings "$DB_URI_VAR_NAME=https://$COSMOS_DB_ACCOUNT_NAME.documents.azure.com:443/"
    elif [ $DATABASE_TYPE = "MONGODB" ]; then
        mongo_cosmos_depl
        az functionapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP --settings "mongoConnectionString=$(az cosmosdb keys list --name $COSMOS_DB_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --type connection-strings | python3 -c "import sys, json; print(json.load(sys.stdin)['connectionStrings'][0]['connectionString'])")"
    fi
    rm depl.json
}

redis_deploy(){
    az redis create --location westeurope --name $REDIS_NAME --resource-group $RESOURCE_GROUP --sku Basic --vm-size c0 --redis-version 6
    az functionapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP --settings "$REDIS_HOSTNAME_VAR_NAME=$REDIS_NAME.redis.cache.windows.net"
    az functionapp config appsettings set --name $APP_NAME --resource-group $RESOURCE_GROUP --settings "$REDIS_KEY_VAR_NAME=$(az redis list-keys --name $REDIS_NAME --resource-group $RESOURCE_GROUP | python3 -c "import sys, json; print(json.load(sys.stdin)['primaryKey'])")"
}

az_fun_deploy(){
    cd ./$AZ_FUN_DIR
    rm -r target
    mvn compile package azure-functions:deploy

    #Add the env vars you wish to your Azure functions app following this template:
    #az functionapp config appsettings set --name "$AZ_FUN_APP_NAME" --resource-group "$RESOURCE_GROUP" --settings "ENV_NAME=ENV_VALUE"

    #az functionapp config appsettings set --name "$AZ_FUN_APP_NAME" --resource-group "$RESOURCE_GROUP" --settings "mongoConnectionString=$(az cosmosdb keys list --name "$COSMOS_DB_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --type connection-strings | python3 -c "import sys, json; print(json.load(sys.stdin)['connectionStrings'][0]['connectionString'])")"
    #az functionapp config appsettings set --name "$AZ_FUN_APP_NAME" --resource-group "$RESOURCE_GROUP" --settings "$DB_NAME_VAR_NAME=$DATABASE_NAME"
  
    #Add connection string of main storage to Azure function
    az functionapp config appsettings set --name $AZ_FUN_APP_NAME --resource-group $RESOURCE_GROUP --settings "BlobStoreConnection=$(az storage account show-connection-string -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME | python3 -c "import sys, json; print(json.load(sys.stdin)['connectionString'])")"
    
    #Add connection string of replica to Azure function
    az functionapp config appsettings set --name $AZ_FUN_APP_NAME --resource-group $RESOURCE_GROUP --settings "$STORAGE_ACCOUNT_REPLICA_CONNECTION_STRING_VAR_NAME=$(az storage account show-connection-string -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_REPLICA_NAME | python3 -c "import sys, json; print(json.load(sys.stdin)['connectionString'])")"

    cd ..
}


az group create -l westeurope -n $RESOURCE_GROUP

#Deploy Web-app to Azure
mvn compile package azure-webapp:deploy

if [ $DEPLOY_CACHE = "Y" ]; then
    redis_deploy &
fi

if [ $DEPLOY_BLOB = "Y" ]; then
    blob_deploy &
fi

if [ $DEPLOY_REPLICA = "Y" ]; then
    blob_replica_deploy &
fi

if [ $DEPLOY_DB = "Y" ]; then
    db_deploy &
fi

wait

if [ "$DEPLOY_AZ_FUN" = "Y" ]; then
    az_fun_deploy
fi
