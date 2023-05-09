import json
import os
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)
env = os.environ.copy()


def lambda_handler(event, context):
  account_role  = env['ORGANIZATIONS_MEMBER_ROLE']
  region_name = env['REGION']

  # check previous step function result if exists
  taskresult = event.get("taskresult", "")

  # check event status
  try:
    create_account_status = event['serviceEventDetails']['createAccountStatus']
  except:
    raise Exception(f"could not access event details")

  # check account id
  if create_account_status['state'] == 'SUCCEEDED':
    account_id = create_account_status['accountId']
  else:
    raise Exception(f"account creation was not successfull!")
  
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
    logger.error(e)
    raise Exception("could not get account name")

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
    logger.error(e)
    raise Exception("limit increase failed!")
  
  # return json
  response_json = {
    "account_name": account_name,
    "account_id": account_id,
  }
  logger.info(f"limits for account '{account_name}' successfully increased")
  return response_json