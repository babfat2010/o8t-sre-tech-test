import boto3
from decimal import Decimal

def seed_data():
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('llm_scores')

    items = [
        {
            'model_name': 'GPT-4',
            'provider': 'OpenAI',
            'context_window': 128000,
            'score': Decimal('95.5')
        },
        {
            'model_name': 'Claude 3 Opus',
            'provider': 'Anthropic',
            'context_window': 200000,
            'score': Decimal('96.0')
        },
        {
            'model_name': 'Llama 3 70B',
            'provider': 'Meta',
            'context_window': 8192,
            'score': Decimal('89.5')
        },
        {
            'model_name': 'Gemini 1.5 Pro',
            'provider': 'Google',
            'context_window': 1000000,
            'score': Decimal('94.8')
        }
    ]

    print(f"Seeding data into table '{table.name}'...")

    with table.batch_writer() as batch:
        for item in items:
            batch.put_item(Item=item)
            print(f"Added {item['model_name']}")

    print("Seeding complete!")

if __name__ == "__main__":
    try:
        seed_data()
    except Exception as e:
        print(f"Error seeding data: {e}")
        print("Ensure you have valid AWS credentials and the table exists.")
