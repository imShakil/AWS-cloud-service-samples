#!/bin/bash

# WordPress HA Nested Stack Deployment Script
# Usage: ./deploy-nested.sh <s3-bucket> <stack-name> <key-pair> [db-password]

S3_BUCKET=${1}
STACK_NAME=${2:-wordpress-ha-nested}
KEY_NAME=${3}
DB_PASSWORD=${4:-MySecurePass123!}

if [ -z "$S3_BUCKET" ] || [ -z "$KEY_NAME" ]; then
    echo "Usage: $0 <s3-bucket> <stack-name> <key-pair> [db-password]"
    echo "Example: $0 my-templates-bucket wordpress-stack my-key-pair"
    exit 1
fi

echo "Uploading nested stack templates to S3..."

# Upload nested stack templates
aws s3 cp network-stack.yaml s3://$S3_BUCKET/
aws s3 cp database-stack.yaml s3://$S3_BUCKET/
aws s3 cp compute-stack.yaml s3://$S3_BUCKET/

echo "Deploying master stack..."

# Deploy master stack
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://master-stack.yaml \
    --parameters ParameterKey=KeyName,ParameterValue=$KEY_NAME \
                 ParameterKey=DBPassword,ParameterValue=$DB_PASSWORD \
                 ParameterKey=TemplateS3Bucket,ParameterValue=$S3_BUCKET \
    --capabilities CAPABILITY_IAM

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME

if [ $? -eq 0 ]; then
    echo "✅ Nested stack deployed successfully!"
    
    WEBSITE_URL=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
        --output text)
    
    echo "🎉 WordPress URL: $WEBSITE_URL"
else
    echo "❌ Stack deployment failed"
    exit 1
fi