#!/bin/bash
# Script to test the image processing workflow on AWS
# Usage: ./image_processing.sh <path_to_image>

set -e  # Exit on error

# Check for required argument
if [ -z "$1" ]; then
  echo "Usage: ./image_processing.sh <path_to_image>"
  exit 1
fi

# Record start time for workflow execution
workflowStart=$(date +%s%3N)

# Set variables
IMAGE_PATH="$1"
FILE_NAME=$(basename "$IMAGE_PATH")
UPLOAD_ENDPOINT="https://hdpyo21c5a.execute-api.us-east-1.amazonaws.com/dev/upload"
PROCESS_ENDPOINT="https://hdpyo21c5a.execute-api.us-east-1.amazonaws.com/dev/process"
REGION="us-east-1"

# --- Invoke uploadImage function ---
echo "Uploading $FILE_NAME..."
ENCODED_IMAGE=$(base64 "$IMAGE_PATH" | tr -d '\n')
TMP_FILE=$(mktemp)
cat <<EOF > "$TMP_FILE"
{
  "image": "$ENCODED_IMAGE",
  "fileName": "$FILE_NAME"
}
EOF

UPLOAD_RESPONSE=$(curl -s -X POST "$UPLOAD_ENDPOINT" -H "Content-Type: application/json" --data @"$TMP_FILE")
rm "$TMP_FILE"

UPLOAD_MESSAGE=$(echo "$UPLOAD_RESPONSE" | jq -r '.message')
if [ "$UPLOAD_MESSAGE" != "Image uploaded successfully!" ]; then
  echo "Upload failed: $UPLOAD_RESPONSE"
  exit 1
fi

UPLOAD_EXEC=$(echo "$UPLOAD_RESPONSE" | jq -r '.executionTime')
echo "Upload successful."

# --- Invoke processImage function ---
echo "Processing $FILE_NAME..."
PROCESS_RESPONSE=$(curl -s -X POST "$PROCESS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{
    \"bucketName\": \"my-new-image-uploads-moaz007\",
    \"fileName\": \"$FILE_NAME\"
  }")

PROCESS_MESSAGE=$(echo "$PROCESS_RESPONSE" | jq -r '.message')
if [ "$PROCESS_MESSAGE" != "Image processed successfully!" ]; then
  echo "Processing failed: $PROCESS_RESPONSE"
  exit 1
fi

PROCESS_EXEC=$(echo "$PROCESS_RESPONSE" | jq -r '.executionTime')
COLD_START=$(echo "$PROCESS_RESPONSE" | jq -r '.coldStart')
echo "Processing successful. Cold start: $COLD_START, Process time: ${PROCESS_EXEC}ms"

# --- Calculate and output total workflow time ---
workflowEnd=$(date +%s%3N)
totalWorkflowTime=$(( workflowEnd - workflowStart ))
echo "Total workflow time: ${totalWorkflowTime}ms"

# --- (Optional) Log the workflow metrics to CloudWatch ---
# This section pushes a log entry to CloudWatch for later review.
UNIFIED_LOG_GROUP="UnifiedWorkflowMetrics"
UNIFIED_LOG_STREAM="workflowRuns"

aws logs create-log-group --log-group-name "$UNIFIED_LOG_GROUP" --region "$REGION" 2>/dev/null || true
aws logs create-log-stream --log-group-name "$UNIFIED_LOG_GROUP" --log-stream-name "$UNIFIED_LOG_STREAM" --region "$REGION" 2>/dev/null || true

SEQUENCE_TOKEN=$(aws logs describe-log-streams --log-group-name "$UNIFIED_LOG_GROUP" --log-stream-name "$UNIFIED_LOG_STREAM" --region "$REGION" --query 'logStreams[0].uploadSequenceToken' --output text 2>/dev/null)
CURRENT_TIME=$(date +%s%3N)

LOG_MESSAGE="Upload time: ${UPLOAD_EXEC}ms, Process time: ${PROCESS_EXEC}ms, Total workflow: ${totalWorkflowTime}ms, Cold start: ${COLD_START}"
if [ "$SEQUENCE_TOKEN" = "None" ] || [ -z "$SEQUENCE_TOKEN" ] || [ "$SEQUENCE_TOKEN" = "null" ]; then
  aws logs put-log-events --log-group-name "$UNIFIED_LOG_GROUP" --log-stream-name "$UNIFIED_LOG_STREAM" --region "$REGION" --log-events "timestamp=$CURRENT_TIME,message=$LOG_MESSAGE" > /dev/null 2>&1
else
  aws logs put-log-events --log-group-name "$UNIFIED_LOG_GROUP" --log-stream-name "$UNIFIED_LOG_STREAM" --region "$REGION" --log-events "timestamp=$CURRENT_TIME,message=$LOG_MESSAGE" --sequence-token "$SEQUENCE_TOKEN" > /dev/null 2>&1
fi

