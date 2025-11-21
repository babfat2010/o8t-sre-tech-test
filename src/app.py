import json
import boto3
import os
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'llm_scores')
table = dynamodb.Table(table_name)

# Helper to handle Decimal serialization
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Lambda handler to retrieve LLM scores.
    This implementation intentionally uses a full table scan for simplicity.
    """
    print("Received event:", json.dumps(event))

    try:
        # Perform a scan (naive approach for demonstration)
        response = table.scan()
        items = response.get('Items', [])

        # Return the list of items
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps(items, cls=DecimalEncoder)
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal Server Error'})
        }
