import json
import boto3

# Inicializa o cliente do AWS IoT Data Plane
# Este cliente é usado para publicar mensagens nos tópicos
iot_client = boto3.client('iot-data')

# O tópico para o qual vamos publicar os comandos
CONTROL_TOPIC = 'esp32/temp/control'

def lambda_handler(event, context):
    """
    Esta função é acionada por uma chamada de API.
    Ela recebe um comando no corpo da requisição e o publica
    no tópico de controlo do AWS IoT.
    """
    print(f"Evento recebido: {event}")

    try:
        # O corpo da requisição (body) vem como uma string JSON,
        # então precisamos de o converter para um objeto Python.
        body = json.loads(event.get('body', '{}'))

        command = body.get('command')
        duration = body.get('duration_seconds')

        # Validação simples para garantir que os dados necessários estão presentes
        if not command or not isinstance(duration, int):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Payload inválido. "command" (string) e "duration_seconds" (int) são obrigatórios.'})
            }

        # Prepara o payload para ser enviado para o ESP32
        payload_to_device = {
            'command': command,
            'duration_seconds': duration
        }

        print(f"A publicar no tópico '{CONTROL_TOPIC}': {payload_to_device}")

        # Publica a mensagem no tópico do AWS IoT
        iot_client.publish(
            topic=CONTROL_TOPIC,
            qos=1, # Quality of Service 1: Garante que a mensagem seja entregue pelo menos uma vez
            payload=json.dumps(payload_to_device)
        )

        # Retorna uma resposta de sucesso para a API
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'message': 'Comando enviado com sucesso!'})
        }

    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'O corpo da requisição não é um JSON válido.'})
        }
    except Exception as e:
        print(f"Ocorreu um erro: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Erro interno do servidor.'})
        }

