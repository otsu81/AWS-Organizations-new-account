

# AWS-organizations-create-new-account
Creates a new account with AWS Organizations, creates some resources and sets permission to a secondary admin AWS account, and sends an SES with the details outlining the details

## Prerequisites
Either a Gmail/Google apps account which can use the + pattern for generating dynamic e-mail addresses, or you need to modify the bash script to use a preconfigured e-mail for registering the new account

AWS CLI installed and configured with appropriate privileges in your `~/.aws/config`

## Required modifications

You have to set a valid e-mails in the bash script, or modify it to use a pattern of your preference.

You have to specify the full path of the Cloudformation script. The format will be different depending if you're on Window or OSX/Linux.

The `createUsersAndGroups.json` Cloudformation template must be modified to use the account you wish to specify as your maintenance account. This can be the same as the Organizations account, but it's best practice to separate maintenance, billing and security into different accounts.

You should modify the SES call to reflect your own e-mail structure.

## Notes
A profile called "cb" will be appended to your `~/.aws/config` file. If you already have a profile called "cb" there might be conflict.

Cloudformation script is executed in the `eu-west-1` (Ireland) region, modify as needed.

The bash script organizations.sh calls for an Account Name. For our internal use that's usually a project name. It will also ask for a "friendly system name" which we internally use for shorthand reference of the account in the registered e-mail and admin role.

There will be two roles in the newly created account:
1. ConsolidatedBillingAuditRole with readonly IAM permissions
2. `admin-[shortname]` with administrator privileges with a trust to another administrator AWS account. Requires MFA token.

The password policy is defined with IAM to be fairly harsh. Modify as needed.

The output is saved as a message and saved in the "messages" directory. If the dir "messages" doesn't exist, it will be created.

SES must be configured and verified for the e-mail addresses used or an error will be thrown. But the information will be saved in a message with timestamp.

## TODO:
1. Enter information in message into a DynamoDB table for safekeeping and future programmatic access
2. Create randomized string for modifying the AWS CLI profile to avoid risking creating a conflict
