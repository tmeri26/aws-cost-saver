import boto3

def lambda_handler(event, context):
    # 1. Connect to the EC2 service in N. Virginia
    ec2 = boto3.client('ec2', region_name='us-east-1')
    
    # 2. Ask AWS to find all servers that are RUNNING AND have our special sticker
    filters = [
        {
            'Name': 'tag:AutoStop',
            'Values': ['true']
        },
        {
            'Name': 'instance-state-name',
            'Values': ['running']
        }
    ]
    
    # 3. Get the list of matching servers
    instances = ec2.describe_instances(Filters=filters)
    
    instance_ids = []
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            instance_ids.append(instance['InstanceId'])
            
    # 4. If we found matching servers, turn them off!
    if len(instance_ids) > 0:
        print(f"Found servers to stop: {instance_ids}")
        ec2.stop_instances(InstanceIds=instance_ids)
        return f"Successfully stopped instances: {instance_ids}"
    else:
        print("No running servers found with AutoStop=true tag.")
        return "No instances to stop."