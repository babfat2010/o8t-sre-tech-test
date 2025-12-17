import json
import boto3
import os
import time
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME', 'llm_scores')
table = dynamodb.Table(table_name)

# === OPTIMIZATION 1: In-Memory Caching ===
# Cache data in Lambda memory (persists across warm invocations)
CACHE_TTL = int(os.environ.get('CACHE_TTL_SECONDS', '300'))  # 5 minutes default
cache = {
    'data': None,
    'timestamp': 0
}

# Helper to handle Decimal serialization
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

### Added New function == Reducing DynamoDB read cost and improvde response time
def get_cached_data():
    """
    Retrieve data from cache if valid, otherwise fetch from DynamoDB.
    This reduces DynamoDB read costs and improves response time.
    """
    current_time = time.time()
    
    # Check if cache is valid
    if cache['data'] and (current_time - cache['timestamp']) < CACHE_TTL:
        cache_age = current_time - cache['timestamp']
        print(json.dumps({
            'event': 'cache_hit',
            'cache_age_seconds': round(cache_age, 2),
            'item_count': len(cache['data'])
        }))
        return cache['data']
    
    # Cache miss or expired - fetch from DynamoDB
    print(json.dumps({
        'event': 'cache_miss',
        'reason': 'expired' if cache['data'] else 'empty',
        'message': 'Fetching from DynamoDB'
    }))
    
    # Measure DynamoDB query time
    db_start = time.time()
    response = table.scan()
    items = response.get('Items', [])
    db_duration = time.time() - db_start
    
    print(json.dumps({
        'event': 'dynamodb_scan_complete',
        'duration_ms': round(db_duration * 1000, 2),
        'item_count': len(items),
        'consumed_capacity': response.get('ConsumedCapacity', 'unknown')
    }))
    
    # Update cache
    cache['data'] = items
    cache['timestamp'] = current_time
    
    return items

def lambda_handler(event, context):
    """
    Enhanced Lambda handler with caching, structured logging, and better error handling.
    NEW improvements added:
    1. In-memory caching to reduce DynamoDB reads (PRIMARY OPTIMIZATION)
    2. Detailed CloudWatch logging for observability
    3. Structured JSON logging for easy querying
    4. Performance metrics tracking (request duration, DynamoDB timing)
    5. Better error handling with request tracking
    """
    # Start timing
    start_time = time.time()
    
    # Structured logging
    request_id = context.request_id if context else 'local'
    source_ip = event.get('requestContext', {}).get('http', {}).get('sourceIp', 'unknown')
    
    print(json.dumps({
        'event': 'request_received',
        'request_id': request_id,
        'path': event.get('rawPath', '/llms'),
        'method': event.get('requestContext', {}).get('http', {}).get('method', 'GET'),
        'source_ip': source_ip,
        'user_agent': event.get('requestContext', {}).get('http', {}).get('userAgent', 'unknown')
    }))

    try:
        # === OPTIMIZATION 2: Use Cached Data ===
        items = get_cached_data()
        
        # Add metadata to response
        is_cached = (time.time() - cache['timestamp']) < CACHE_TTL
        response_body = {
            'data': items,
            'count': len(items),
            'cached': is_cached,
            'cache_age_seconds': round(time.time() - cache['timestamp'], 2)
        }
        
        # Calculate total request duration
        total_duration = time.time() - start_time
        
        print(json.dumps({
            'event': 'request_success',
            'request_id': request_id,
            'item_count': len(items),
            'cached': is_cached,
            'total_duration_ms': round(total_duration * 1000, 2),
            'status_code': 200
        }))

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'X-Cache-Status': 'HIT' if is_cached else 'MISS',
                'X-Request-Id': request_id,
                'X-Response-Time': f"{round(total_duration * 1000, 2)}ms"
            },
            'body': json.dumps(response_body, cls=DecimalEncoder)
        }

    except Exception as e:
        error_message = str(e)
        error_duration = time.time() - start_time
        
        print(json.dumps({
            'event': 'request_error',
            'request_id': request_id,
            'error': error_message,
            'error_type': type(e).__name__,
            'duration_ms': round(error_duration * 1000, 2),
            'status_code': 500
        }))
        
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'X-Request-Id': request_id,
                'X-Response-Time': f"{round(error_duration * 1000, 2)}ms"
            },
            'body': json.dumps({
                'error': 'Internal Server Error',
                'request_id': request_id
            })
        }