import boto3
import time

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("ReadForMe")
polly = boto3.client('polly')
s3 = boto3.client("s3")

def lambda_handler(event, context):
    try:
        print(event)
        job_id = event['job_id']
        text = event['text']
        file_name = event['file_name']

        response = polly.synthesize_speech(
            Text=text,
            OutputFormat='mp3',
            VoiceId='Joanna',
            Engine='neural'
        )

        audio_file = file_name.rsplit(".", 1)[0] + ".mp3"

        if 'AudioStream' in response:
            s3.upload_fileobj(
                response['AudioStream'], 
                "read-for-me", 
                audio_file,
                ExtraArgs={'ContentType': 'audio/mpeg'}
            )
            print(f"Successfully uploaded audio to s3://read-for-me/{audio_file}")

            table.update_item(
            Key={
                'jobId': job_id   
            },
            UpdateExpression="SET #status = :status, #updatedAt = :updatedAt, #outputS3Key = :outputS3Key",
            ExpressionAttributeNames={
                "#status": "status",
                "#updatedAt": "updatedAt",
                "#outputS3Key": "outputS3Key"
            },
            ExpressionAttributeValues={
                ":updatedAt": str(time.time()),
                ":status": "AUDIO_GENERATION_DONE",
                ":outputS3Key": audio_file
            },
            ReturnValues="UPDATED_NEW"
        )

        print(f"Dynamo entry updated for jobId: {job_id}")
    except Exception as e:
        print(f"Failure: {e}")
        raise