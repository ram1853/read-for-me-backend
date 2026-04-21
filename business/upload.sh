#!/bin/zsh

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: $0 userName fileName filePath"
    echo "Description: This script generates a s3 pre-signed url & uses that url to upload a jpg file"
    echo "Example: ./upload.sh ram1853 dog.jpg /Users/bob/Downloads/dog.jpg"
    exit 0
fi

userName=$1
fileName=$2
filePath=$3

response=$(curl -s -H "Content-Type: application/json" -d '{"userName": "'$userName'", "fileName": "'$fileName'"}' https://sa59m16bwg.execute-api.ap-south-1.amazonaws.com/dev/upload-url)

URL=$(echo "$response" | jq -r '.url')
contentType=$(echo "$response" | jq -r '.content_type')

echo "S3 Presigned URL:"
echo $URL

echo "Content Type:"
echo $contentType

uploadStatus=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: $contentType" -T $filePath "$URL")

if [ "$uploadStatus" -eq 200 ]; then
    echo "Upload successful"
else
    echo "Upload failed (HTTP $uploadStatus)"
fi