import json
import os
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)
env = os.environ.copy()


def lambda_handler(event, context):
  account_role  = env['ORGANIZATIONS_MEMBER_ROLE_NAME']
  suspended_ou_id = env['SUSPENDED_OU_ID']
  region_name = env['REGION']

  # check event status
  close_account_status = event['detail']['serviceEventDetails']['closeAccountStatus']
  account_id = None
  if close_account_status['state'] == 'SUCCEEDED':
    account_id = close_account_status['accountId']
  else:
    raise Exception(f"Account suspension was not successfull!")
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

  # init organizations client
  logger.info(f"move suspended account to suspended OU")
  try:
    organizations_client = boto3.client(
      'organizations', 
      region_name=region_name,
      aws_access_key_id = org_mgmt_credentials['AccessKeyId'],
      aws_secret_access_key = org_mgmt_credentials['SecretAccessKey'],
      aws_session_token = org_mgmt_credentials['SessionToken'],
    )

    # get account name
    response = organizations_client.describe_account(AccountId=account_id)
    account_name = response["Account"]["Name"]

    # get root id where suspended account will be placed
    response = organizations_client.list_roots()
    root_id = response['Roots'][0]['Id']

    # get account ids in root ou
    response = organizations_client.list_accounts_for_parent(
      ParentId=root_id,
    )

    # check if closed account is in root ou
    root_ou_account_ids = []
    for account in response['Accounts']:
      root_ou_account_ids += account['Id']
    if account_id not in root_ou_account_ids:
      raise Exception(f"suspended account '{account_name}' is not in root OU as expected!")

    # move account to suspended ou
    response = organizations_client.move_account(
      AccountId=account_id,
      SourceParentId=root_id,
      DestinationParentId=suspended_ou_id
    )
  except Exception as e:
    logger.info(f"moving suspended account '{account_name}' to suspended OU failed!")
    logger.error(e)
    pass
  
  # return json
  response_json = {
    "account_name": account_name,
    "account_id": account_id,
  }
  logger.info(f"suspended account '{account_name}' was successfully moved to suspended OU")
  return response_json