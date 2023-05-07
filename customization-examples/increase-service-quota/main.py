import json
import os
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)
env = os.environ.copy()


def lambda_handler(event, context):
  account_role  = env['ORGANIZATIONS_MEMBER_ROLE_NAME']
  region_name = env['REGION']

  # check event status
  create_account_status = event['detail']['serviceEventDetails']['createAccountStatus']
  account_id = None
  if create_account_status['state'] == 'SUCCEEDED':
    account_id = create_account_status['accountId']
  else:
    raise Exception("Account creation was not Successfull!")
  logger.info(f"account_id: {account_id}")

  # new quotas
  quota_increases = [
    {
      'ServiceCode':'iam',
      'QuotaCode':'L-0DA4ABF3',
      'DesiredValue': 20
    }
  ]

  # assume org mgmt role
  logger.info(f"assume Organizations member role in org management acccount")
  sts_client = boto3.client('sts', region_name=region_name)
  assumedRoleObject = sts_client.assume_role(RoleArn=account_role, RoleSessionName="ntc-account-factory")
  org_mgmt_credentials = assumedRoleObject['Credentials']
  
  sts_org_mgmt = boto3.client(
    'sts', 
    region_name=region_name,
    aws_access_key_id = org_mgmt_credentials['AccessKeyId'],
    aws_secret_access_key = org_mgmt_credentials['SecretAccessKey'],
    aws_session_token = org_mgmt_credentials['SessionToken'],
  )

  # get account info
  logger.info(f"get account name")
  try:
    organizations_client = boto3.client(
      'organizations', 
      region_name=region_name,
      aws_access_key_id = org_mgmt_credentials['AccessKeyId'],
      aws_secret_access_key = org_mgmt_credentials['SecretAccessKey'],
      aws_session_token = org_mgmt_credentials['SessionToken'],
    )
    response = organizations_client.describe_account(AccountId=account_id)
    account_name = response["Account"]["Name"]
  except Exception as e:
    logger.info("could not get account name!")
    logger.error(e)
    pass

  # assume org member role
  logger.info(f"assume Organizations member role in acccount '{account_name}'")
  role_arn = f"arn:aws:iam::{account_id}:role/{account_role}"
  assumedRoleObject = sts_org_mgmt.assume_role(RoleArn=role_arn, RoleSessionName="ntc-account-factory")
  client_credentials = assumedRoleObject['Credentials']

  # increase limits
  logger.info(f"increase limits")
  try:
    quota_client = boto3.client('service-quotas',
      aws_access_key_id = client_credentials['AccessKeyId'],
      aws_secret_access_key = client_credentials['SecretAccessKey'],
      aws_session_token = client_credentials['SessionToken'],
      region_name='us-east-1'
    )
    for quota_limit in quota_increases:
      response = quota_client.request_service_quota_increase(
        ServiceCode=quota_limit['ServiceCode'],
        QuotaCode=quota_limit['QuotaCode'],
        DesiredValue=quota_limit['DesiredValue']
      )
    logger.info(f"limit increase successfully requested!")
  except Exception as e:
    logger.info(f"limit increase failed!")
    logger.error(e)
    pass
  
  # return json
  response_json = {
    "account_name": account_name,
    "account_id": account_id,
  }
  logger.info(f"limits for account '{account_name}' successfully increased")
  return response_json