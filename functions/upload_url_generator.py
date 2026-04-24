import json
import boto3
import mimetypes
import uuid

def generate_presigned_url(s3_client, bucket, key, expires_in):
   content_type, _ = mimetypes.guess_type(key)
   job_id = str(uuid.uuid4())
   if not content_type:
      content_type = 'application/octet-stream'
   url = s3_client.generate_presigned_url('put_object', Params={
        'Bucket': bucket,
        'Key': key,
        'ContentType': content_type, 
        'Metadata': {"job_id": job_id}
        }, ExpiresIn=expires_in)
   
   return {
      "statusCode": 200,
      "headers": {
            "Access-Control-Allow-Origin": "*",
        },
      "body": json.dumps({"url": url, "content_type": content_type, "job_id": job_id})
   }

def lambda_handler(event, context):
   try:
    print(event)
    body = json.loads(event['body'])
    userName = body.get('userName')
    fileName = body.get('fileName')

    s3_client = boto3.client("s3", region_name="ap-south-1")

    # The presigned URL is specified to expire in 1000 seconds
    return generate_presigned_url(s3_client, "read-for-me", userName+"/files/"+fileName, 1000)
   except Exception as e:
        print(f"Couldn't get a presigned URL for client method.")
        raise