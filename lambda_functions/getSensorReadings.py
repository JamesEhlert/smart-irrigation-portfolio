import json
import boto3
import base64
from decimal import Decimal # Importamos a classe Decimal

# Inicializa o cliente do DynamoDB
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('IoTDeviceReadings')

class DecimalEncoder(json.JSONEncoder):
    """
    Classe auxiliar para converter o tipo Decimal do DynamoDB para float,
    que é um formato que o JSON entende.
    """
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    """
    Esta função é acionada por uma chamada de API.
    Ela busca as últimas leituras de um dispositivo específico no DynamoDB
    e suporta paginação segura com Base64.
    """
    print(f"Evento recebido: {event}")

    try:
        params = event.get('queryStringParameters', {})
        thing_id = params.get('thingId')
        limit = int(params.get('limit', 50))

        if not thing_id:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'O parâmetro "thingId" é obrigatório.'})
            }

        query_kwargs = {
            'KeyConditionExpression': boto3.dynamodb.conditions.Key('thingId').eq(thing_id),
            'ScanIndexForward': False,
            'Limit': limit
        }

        # --- LÓGICA DE PAGINAÇÃO (DECODIFICAÇÃO) ---
        last_key_b64 = params.get('exclusiveStartKey')
        if last_key_b64:
            last_key_json = base64.b64decode(last_key_b64).decode('utf-8')
            # **** A CORREÇÃO ESTÁ AQUI ****
            # Usamos parse_float=Decimal para garantir que os números sejam lidos
            # de volta para o formato que o DynamoDB espera.
            query_kwargs['ExclusiveStartKey'] = json.loads(last_key_json, parse_float=Decimal)

        response = table.query(**query_kwargs)
        items = response.get('Items', [])
        
        response_body = {
            'items': items
        }
        
        # --- LÓGICA DE PAGINAÇÃO (CODIFICAÇÃO) ---
        last_evaluated_key = response.get('LastEvaluatedKey')
        if last_evaluated_key:
            last_key_json = json.dumps(last_evaluated_key, cls=DecimalEncoder)
            response_body['exclusiveStartKey'] = base64.b64encode(last_key_json.encode('utf-8')).decode('utf-8')
        
        print(f"Encontrados {len(items)} itens. Há mais páginas? {'Sim' if last_evaluated_key else 'Não'}")

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(response_body, cls=DecimalEncoder)
        }

    except Exception as e:
        print(f"Ocorreu um erro: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Erro interno do servidor.'})
        }