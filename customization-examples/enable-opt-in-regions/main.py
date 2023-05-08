import json
import os
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)
env = os.environ.copy()


def lambda_handler(event, context):
  opt_in_regions = json.loads(env['OPT_IN_REGIONS'])
  account_role  = env['ORGANIZATIONS_MEMBER_ROLE']
  region_name = env['REGION']

  # check event status
  create_account_status = event['detail']['serviceEventDetails']['createAccountStatus']
  account_id = None
  if create_account_status['state'] == 'SUCCEEDED':
    account_id = create_account_status['accountId']
  else:
    raise Exception("Account creation was not Successfull!")
  logger.info(f"account_id: {account_id}")

  # assume org mgmt role
  logger.info(f"assume Organizations member role in org management acccount")
  sts_client = boto3.client('sts', region_name=region_name)
  assumedRoleObject = sts_client.assume_role(RoleArn=account_role, RoleSessionName="ntc-account-factory")
  org_mgmt_credentials = assumedRoleObject['Credentials']
  
  # sts_org_mgmt = boto3.client(
  #   'sts', 
  #   region_name=region_name,
  #   aws_access_key_id = org_mgmt_credentials['AccessKeyId'],
  #   aws_secret_access_key = org_mgmt_credentials['SecretAccessKey'],
  #   aws_session_token = org_mgmt_credentials['SessionToken'],
  # )

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

  # enable opt-in regions
  logger.info("Enabling opt-in regions")
  for region in opt_in_regions:
    try:
      account = boto3.client(
        'account',
        region_name=region_name,
        aws_access_key_id = org_mgmt_credentials['AccessKeyId'],
        aws_secret_access_key = org_mgmt_credentials['SecretAccessKey'],
        aws_session_token = org_mgmt_credentials['SessionToken'],
      )

      response = account.enable_region(
          AccountId=account_id,
          RegionName=region
      )

      logger.info(f"region '{region}' successfully enabled!")
    except Exception as e:
      logger.info(f"failed to enable region '{region}'.")
      logger.error(e)
      pass

  # return json
  response_json = {
    "account_name": account_name,
    "account_id": account_id,
  }
  logger.info("opt-in regions for account '{account_name}' successfully activated")
  return response_json