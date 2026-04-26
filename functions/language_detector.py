import boto3
import time

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("ReadForMe")
comprehend = boto3.client("comprehend")

def lambda_handler(event, context):
    try:
        print(event)
        job_id = event['job_id']
        text = event['text']
        audio_language = event['audio_language']
        file_name = event['file_name']

        dominant_languages = comprehend.detect_dominant_language(Text=text)
        top_dominant_language = dominant_languages['Languages'][0]
        print(top_dominant_language)

        table.update_item(
            Key={
                'jobId': job_id   
            },
            UpdateExpression="SET #status = :status, #updatedAt = :updatedAt",
            ExpressionAttributeNames={
                "#status": "status",
                "#updatedAt": "updatedAt"
            },
            ExpressionAttributeValues={
                ":updatedAt": str(time.time()),
                ":status": "DOMINANT_LANGUAGE_DETECTED"
            },
            ReturnValues="UPDATED_NEW"
        )

        print(f"Dynamo entry updated for jobId: {job_id}")

        return {"job_id": job_id, "dominant_language": top_dominant_language['LanguageCode'],
                 "audio_language": audio_language, "text": text, "file_name": file_name}
        
    except Exception as e:
        print(f"Failure: {e}")
        raise