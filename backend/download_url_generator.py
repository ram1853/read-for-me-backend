import boto3
import json

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("ReadForMe")
s3 = boto3.client("s3")

def generate_presigned_url(s3, bucket, job_id, expires_in):
   
   response = table.get_item(Key={'jobId': job_id})
   status = ''
   download_url = ''
   item = response.get('Item')
   if(item):
      status = item['status']
      if(status == 'AUDIO_GENERATION_DONE'):
         audio_key = item['outputS3Key']
         download_url = s3.generate_presigned_url(
            ClientMethod='get_object',
            Params={
                'Bucket': bucket,
                'Key': audio_key
            },
            ExpiresIn=3600  
            )
      else:
         print(f"Audio generation not completed yet, current status is: {status}")
         
   else:
      raise Exception(f"No dynamo item found for jobId: {job_id}")
   
   return {
      "statusCode": 200,
      "headers": {
            "Access-Control-Allow-Origin": "*",
        },
      "body": json.dumps({"status": status, "download_url": download_url})
   }

def lambda_handler(event, context):
   try:
    print(event)
    body = json.loads(event['body'])
    job_id = body.get('job_id')

   # The presigned URL is specified to expire in 1000 seconds
    return generate_presigned_url(s3, "read-for-me", job_id, 1000)
   except Exception as e:
        print(f"Couldn't get a presigned URL: {e}")
        raise