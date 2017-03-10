#!/bin/bash

# location of cloudformation scripts
CF_LOCATION="/Users/user/Documents/AWS/code/cloudformation"

echo "Enter account name: "
read PROJ_NAME
echo "Enter short system friendly name: "
read SHORT_NAME

CAS_ID="$(aws organizations create-account --email invalidaddress+$SHORT_NAME@gmail.com --account-name "$PROJ_NAME" --role-name ConsolidatedBillingAuditRole --iam-user-access-to-billing ALLOW --region us-east-1 --query 'CreateAccountStatus.Id' --output text)"

echo $CAS_ID

DURATION=30
# sleep for $DURATION seconds to wait for account to finish creating
echo "Wait for $DURATION seconds to wait for account to create..."
DOT="."
for i in `seq 1 $DURATION`;
do
 sleep 1
 echo -ne $DOT
done
echo -ne '\n'

echo $(aws organizations describe-create-account-status --create-account-request-id $CAS_ID --query 'CreateAccountStatus.AccountId' --region us-east-1)

ACC_NBR="$(aws organizations describe-create-account-status --create-account-request-id $CAS_ID --query 'CreateAccountStatus.AccountId' --region us-east-1 --output text)"

echo ""
echo "Account number: $ACC_NBR"

# create new profile with the new account number to roleswitch into
cp ~/.aws/config ~/.aws/config.bak

echo -e "" >> ~/.aws/config
echo -e "[profile cb]" >> ~/.aws/config
echo -e "role_arn = arn:aws:iam::$ACC_NBR:role/ConsolidatedBillingAuditRole" >> ~/.aws/config
echo -e "source_profile = default" >> ~/.aws/config

# update password policy for the new account with role in new account according to profile
aws iam update-account-password-policy --minimum-password-length 8 --require-symbols --require-uppercase-characters --require-lowercase-characters --require-numbers --allow-users-to-change-password --max-password-age 45 --password-reuse-prevention 10 --profile cb

# copy the cloudformation JSON file to current directory, modify "admin-role" to reflect new name
cp $CF_LOCATION/createGroupsAndUsers.json ./temp.json
sed -ie "s/admin-role/admin-$SHORT_NAME/g" temp.json

# create admin group and CDT role for switch using the JSON file permissions, with role in new account
aws cloudformation create-stack --stack-name "AdminCF" --template-body file://./temp.json --capabilities CAPABILITY_NAMED_IAM --tags Key="owner",Value="Cloud team" --region eu-west-1 --profile cb

# function for timestamping the SES message
function timestamp {
  date +"%Y-%m-%d.%H:%M"
}

# check if dir $DIRECTORY exists
DIRECTORY=messages
if [ ! -d "$DIRECTORY" ]; then
  mkdir $DIRECTORY
fi

# write log message for safekeeping just in case
echo "{
   \"Subject\": {
       \"Data\": \"New account created in Consolidated Billing account\",
       \"Charset\": \"UTF-8\"
   },
   \"Body\": {
       \"Text\": {
           \"Data\": \"A new account has been created with the following info:\",
           \"Charset\": \"UTF-8\"
       },
       \"Html\": {
           \"Data\": \"Project name: $PROJ_NAME<br>\
           E-mail: invalidaddress+$SHORT_NAME@gmail.com<br>\
           Role name: cdtadmin-$SHORT_NAME<br>\
           Role switch URL: https://signin.aws.amazon.com/switchrole?account=$ACC_NBR&roleName=admin-$SHORT_NAME \
           \",
           \"Charset\": \"UTF-8\"
       }
   }
}
" > ./messages/message."$(timestamp)".json

# send confirmation e-mail with SES
aws ses send-email --from your.own@email.com --to consolidated-billing@email.com --message file://$PWD/messages/message."$(timestamp)".json --region eu-west-1

# sleep DURATION to wait for cloudformation to finish creating resources before cleaning up permissions
DURR=60
echo "Waiting $DURR seconds for CloudFormation to finish creating assets..."
for i in `seq 1 $DURR`;
do
 sleep 1
 echo -ne $DOT
done
echo -ne '\n'

# clean up IAM permissions for ConsolidatedBillingAuditRole to only allow audit, with CB profile
aws iam attach-role-policy --role-name ConsolidatedBillingAuditRole --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess --profile cb
aws iam delete-role-policy --role-name ConsolidatedBillingAuditRole --policy-name AdministratorAccess --profile cb

# cleanup/delete the temporary files from local computer for the new account
cp ~/.aws/config.bak ~/.aws/config
rm ~/.aws/config.bak
rm temp.json*
