import boto3
import time

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("ReadForMe")
translate = boto3.client('translate')

def lambda_handler(event, context):
    try:
        print(event)
        job_id = event['job_id']
        source_language = event['dominant_language']
        target_language = event['audio_language']
        text = event['text']
        file_name = event['file_name']

        if(source_language == target_language):
            print("Source & Target Language are same. No translation needed")
            return {"job_id": job_id, "text": text}
        
        response = translate.translate_text(
            Text=text,
            SourceLanguageCode=source_language,
            TargetLanguageCode=target_language
        )

        translated_text = response.get('TranslatedText')

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
                ":status": "TEXT_TRANSLATION_DONE"
            },
            ReturnValues="UPDATED_NEW"
        )

        print(f"Dynamo entry updated for jobId: {job_id}")

        return {"job_id": job_id, "text": translated_text, "file_name": file_name}

    except Exception as e:
        print(f"Failure: {e}")
        raise