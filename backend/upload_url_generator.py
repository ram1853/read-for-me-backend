import json
import boto3
import mimetypes
import uuid

s3_client = boto3.client("s3")

def generate_presigned_url(s3_client, bucket, key, expires_in, audio_language):
   content_type, _ = mimetypes.guess_type(key)
   job_id = str(uuid.uuid4())
   if not content_type:
      content_type = 'application/octet-stream'
   url = s3_client.generate_presigned_url('put_object', Params={
        'Bucket': bucket,
        'Key': key,
        'ContentType': content_type, 
        'Metadata': {"job_id": job_id, "audio_language": audio_language}
        }, ExpiresIn=expires_in)
   
   return {
      "statusCode": 200,
      "headers": {
            "Access-Control-Allow-Origin": "*"
        },
      "body": json.dumps({"url": url, "content_type": content_type, "job_id": job_id})
   }

def lambda_handler(event, context):
   try:
    print(event)
    body = json.loads(event['body'])
    userName = body.get('userName')
    fileName = body.get('fileName')
    audioLanguage = body.get('audioLanguage')

   # The presigned URL is specified to expire in 1000 seconds
    return generate_presigned_url(s3_client, "read-for-me", userName+"/files/"+fileName, 1000, audioLanguage)
   except Exception as e:
        print(f"Couldn't get a presigned URL for client method.")
        raise