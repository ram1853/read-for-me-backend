import boto3
import time

s3_client = boto3.client("s3")
textract_client = boto3.client("textract")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("ReadForMe")
def lambda_handler(event, context):
   try:
    print(event)
    bucket = event['detail']['bucket']['name']
    key = event['detail']['object']['key']
    response = s3_client.head_object(Bucket=bucket, Key=key)
    job_id = response["Metadata"]["job_id"]
    audio_language = response["Metadata"]["audio_language"]

    response = textract_client.detect_document_text(
    Document={
        'S3Object': {
            'Bucket': bucket,
            'Name': key
        }
    }
    )
    text = "\n".join(
      block['Text']
      for block in response['Blocks']
      if block['BlockType'] == 'LINE'
    )
    
    table.put_item(
       Item = {
          'jobId': job_id,
          'userId': "vishnu",
          'status': 'TEXT_EXTRACTED',
          'inputS3Key': key,
          'createdAt': str(time.time()),
          'TimeToExist': int(time.time()) + (24 * 60 * 60)
       }
    )

    print(f"Dynamo entry created for jobId: {job_id}")

    return {"text": text, "job_id": job_id, "audio_language": audio_language, "file_name": key};
   except Exception as e:
        print(f"Failure: {e}")
        raise