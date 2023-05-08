import json
import os
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)
env = os.environ.copy()
vpc_id = []


def lambda_handler(event, context):
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

  # get active regions
  logger.info("Get all active AWS Regions")
  ec2_client = boto3.client('ec2', region_name=region_name)
  regions = get_regions(ec2_client)

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

  logger.info("Start default vpc deletion")
  for region in regions:

    ec2_client= boto3.client(
      'ec2', 
      region_name=region,
      aws_access_key_id = client_credentials['AccessKeyId'],
      aws_secret_access_key = client_credentials['SecretAccessKey'],
      aws_session_token = client_credentials['SessionToken']
    )

    try:
      attribs = ec2_client.describe_account_attributes(AttributeNames=[ 'default-vpc' ])['AccountAttributes']
    except ClientError as e:
      logger.error(e.response['Error'])
      continue

    else:
      vpc_id = attribs[0]['AttributeValues'][0]['AttributeValue']

    if vpc_id == 'none':
      logger.info('VPC (default) was not found in the {} region.'.format(region))
      continue
    # Are there any existing resources?  Since most resources attach an ENI, let's check..

    args = {
      'Filters' : [
        {
          'Name' : 'vpc-id',
          'Values' : [ vpc_id ]
        }
      ]
    }

    try:
      eni = ec2_client.describe_network_interfaces(**args)['NetworkInterfaces']
    except ClientError as e:
      logger.error(e.response['Error'])
      continue

    if eni:
      logger.info('VPC {} has existing resources in the {} region.'.format(vpc_id, region))
      continue


    result = delete_igw(ec2_client, vpc_id)
    result = delete_subs(ec2_client, args)
    result = delete_rtbs(ec2_client, args)
    result = delete_acls(ec2_client, args)
    result = delete_sgps(ec2_client, args)
    result = delete_vpc(ec2_client, vpc_id, region)


  response_json = {
    "account_name": account_name,
    "account_id": account_id,
  }
  logger.info("default vpcs are deleted")
  return response_json


def delete_igw(ec2_client, vpc_id):
  """
  Detach and delete the internet gateway
  """

  args = {
    'Filters' : [
      {
        'Name' : 'attachment.vpc-id',
        'Values' : [ vpc_id ]
      }
    ]
  }

  try:
    igw = ec2_client.describe_internet_gateways(**args)['InternetGateways']
  except ClientError as e:
    logger.error(e.response['Error'])

  if igw:
    igw_id = igw[0]['InternetGatewayId']

    try:
      result = ec2_client.detach_internet_gateway(InternetGatewayId=igw_id, VpcId=vpc_id)
    except ClientError as e:
      logger.error(e.response['Error'])

    try:
      result = ec2_client.delete_internet_gateway(InternetGatewayId=igw_id)
    except ClientError as e:
      logger.error(e.response['Error'])

  return


def delete_subs(ec2_client, args):
  """
  Delete the subnets
  """

  try:
    subs = ec2_client.describe_subnets(**args)['Subnets']
  except ClientError as e:
    logger.error(e.response['Error'])

  if subs:
    for sub in subs:
      sub_id = sub['SubnetId']

      try:
        result = ec2_client.delete_subnet(SubnetId=sub_id)
      except ClientError as e:
        logger.error(e.response['Error'])

  return


def delete_rtbs(ec2_client, args):
  """
  Delete the route tables
  """

  try:
    rtbs = ec2_client.describe_route_tables(**args)['RouteTables']
  except ClientError as e:
    logger.error(e.response['Error'])

  if rtbs:
    for rtb in rtbs:
      main = 'false'
      for assoc in rtb['Associations']:
        main = assoc['Main']
      if main == True:
        continue
      rtb_id = rtb['RouteTableId']

      try:
        result = ec2_client.delete_route_table(RouteTableId=rtb_id)
      except ClientError as e:
        logger.error(e.response['Error'])

  return


def delete_acls(ec2_client, args):
  """
  Delete the network access lists (NACLs)
  """

  try:
    acls = ec2_client.describe_network_acls(**args)['NetworkAcls']
  except ClientError as e:
    logger.error(e.response['Error'])

  if acls:
    for acl in acls:
      default = acl['IsDefault']
      if default == True:
        continue
      acl_id = acl['NetworkAclId']

      try:
        result = ec2_client.delete_network_acl(NetworkAclId=acl_id)
      except ClientError as e:
        logger.error(e.response['Error'])

  return


def delete_sgps(ec2_client, args):
  """
  Delete any security groups
  """

  try:
    sgps = ec2_client.describe_security_groups(**args)['SecurityGroups']
  except ClientError as e:
    logger.error(e.response['Error'])

  if sgps:
    for sgp in sgps:
      default = sgp['GroupName']
      if default == 'default':
        continue
      sg_id = sgp['GroupId']

      try:
        result = ec2_client.delete_security_group(GroupId=sg_id)
      except ClientError as e:
        logger.error(e.response['Error'])

  return


def delete_vpc(ec2_client, vpc_id, region):
  """
  Delete the VPC
  """

  try:
    result = ec2_client.delete_vpc(VpcId=vpc_id)
  except ClientError as e:
    logger.error(e.response['Error'])

  else:
    logger.info('VPC {} has been deleted from the {} region.'.format(vpc_id, region))

  return


def get_regions(ec2_client):
  """
  Return all AWS regions
  """

  regions = []

  try:
    aws_regions = ec2_client.describe_regions()['Regions']
  except ClientError as e:
    logger.error(e.response['Error'])

  else:
    for region in aws_regions:
      regions.append(region['RegionName'])

  return regions