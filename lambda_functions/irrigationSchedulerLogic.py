import json
import boto3
import os
import datetime
import pytz # Para lidar com fusos horários

# Importa as bibliotecas do Google Cloud
from google.oauth2 import service_account
from google.cloud import firestore

# --- Configuração Inicial ---
secrets_manager = boto3.client('secretsmanager')
dynamodb = boto3.resource('dynamodb')
iot_client = boto3.client('iot-data')

GCP_SECRET_NAME = "gcp/firestore-credentials"
CONTROL_TOPIC = 'esp32/temp/control'

# --- Variáveis Globais (inicializadas uma vez) ---
firestore_client = None
dynamodb_table = None

def get_firestore_client():
    """
    Busca as credenciais do Google Cloud no AWS Secrets Manager e inicializa
    o cliente do Firestore. Faz cache do cliente para execuções futuras.
    """
    global firestore_client
    if firestore_client:
        return firestore_client

    print("A inicializar o cliente do Firestore pela primeira vez...")
    secret_response = secrets_manager.get_secret_value(SecretId=GCP_SECRET_NAME)
    secret_string = secret_response['SecretString']
    gcp_credentials_dict = json.loads(secret_string)

    # --- LINHA DE DEPURAÇÃO ADICIONADA ---
    # Extrai o ID do projeto diretamente do ficheiro de credenciais para sabermos a qual projeto estamos a ligar.
    project_id = gcp_credentials_dict.get('project_id')
    print(f"Conectado ao projeto Google Cloud ID: {project_id}")
    # ------------------------------------

    credentials = service_account.Credentials.from_service_account_info(gcp_credentials_dict)
    firestore_client = firestore.Client(credentials=credentials)
    print("Cliente do Firestore inicializado com sucesso.")
    return firestore_client

def get_dynamodb_table():
    """
    Inicializa a tabela do DynamoDB. Faz cache para execuções futuras.
    """
    global dynamodb_table
    if dynamodb_table:
        return dynamodb_table
    dynamodb_table = dynamodb.Table('IoTDeviceReadings')
    return dynamodb_table

def lambda_handler(event, context):
    """
    Esta função é acionada a cada minuto pelo EventBridge.
    Ela verifica se há agendamentos a serem executados.
    """
    try:
        tz = pytz.timezone('America/Sao_Paulo')
        now = datetime.datetime.now(tz)
        current_time_str = now.strftime('%H:%M')
        current_day_str = now.strftime('%A').lower()

        print(f"Verificação às {current_time_str} de {current_day_str} (BRT)")

        db = get_firestore_client()
        readings_table = get_dynamodb_table()

        schedules_ref = db.collection_group('schedules').where('startTime', '==', current_time_str).where('daysOfWeek', 'array_contains', current_day_str).where('isEnabled', '==', True)
        
        schedules_to_run = list(schedules_ref.stream())

        if not schedules_to_run:
            print("Nenhum agendamento para executar neste minuto.")
            return {'statusCode': 200, 'body': 'Nenhum agendamento.'}

        print(f"Encontrados {len(schedules_to_run)} agendamento(s) para executar.")

        for schedule in schedules_to_run:
            schedule_data = schedule.to_dict()
            device_ref = schedule.reference.parent.parent
            device_data = device_ref.get().to_dict()

            thing_id = device_data.get('thingId')
            max_moisture = device_data.get('maxMoistureThreshold')
            duration = schedule_data.get('durationMinutes') * 60

            if not all([thing_id, max_moisture, duration]):
                print(f"ERRO: Dados incompletos para o agendamento {schedule.id}. A saltar.")
                continue

            response = readings_table.query(
                KeyConditionExpression=boto3.dynamodb.conditions.Key('thingId').eq(thing_id),
                ScanIndexForward=False,
                Limit=1
            )
            
            latest_reading = response['Items'][0] if response.get('Items') else None

            if not latest_reading:
                print(f"Nenhuma leitura encontrada para o thingId {thing_id}. A saltar.")
                continue

            current_moisture = latest_reading.get('readings', {}).get('temperature')

            log_ref = device_ref.collection('executionLogs').document()

            if current_moisture < max_moisture:
                print(f"A humidade ({current_moisture}) está abaixo do limite ({max_moisture}). A acionar a irrigação.")
                
                command_payload = json.dumps({
                    "command": "open_valve",
                    "duration_seconds": duration
                })
                
                iot_client.publish(topic=CONTROL_TOPIC, qos=1, payload=command_payload)
                
                log_ref.set({
                    "timestamp": firestore.SERVER_TIMESTAMP,
                    "scheduledTime": current_time_str,
                    "actionTaken": "executed",
                    "reason": f"Irrigação acionada por {duration/60} minutos."
                })
            else:
                print(f"A humidade ({current_moisture}) está ACIMA do limite ({max_moisture}). A saltar a irrigação.")
                
                log_ref.set({
                    "timestamp": firestore.SERVER_TIMESTAMP,
                    "scheduledTime": current_time_str,
                    "actionTaken": "skipped",
                    "reason": f"A humidade ({current_moisture}) estava acima do limite ({max_moisture})."
                })

        return {'statusCode': 200, 'body': 'Verificação concluída.'}

    except Exception as e:
        print(f"ERRO GERAL NA EXECUÇÃO: {e}")
        raise e
