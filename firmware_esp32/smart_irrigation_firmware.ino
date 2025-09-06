// ==========================================================================
// PROJETO: ESP32-C3 com AHT10 -> AWS IoT (Versão com Controlo Remoto)
// Autor: Gemini (baseado no código original)
// Data: 2025-08-23
// Descrição: Versão final com controlo de uma válvula (LED) via MQTT.
//            Otimizado para publicação a cada 3 segundos.
// ==========================================================================

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_AHTX0.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include "time.h"
#include "secrets.h"

// ==============================================================
// ----------------- Configurações de Hardware ------------------
#define SDA_PIN 8
#define SCL_PIN 9
#define OLED_ADDR       0x3C
#define SCREEN_WIDTH    128
#define SCREEN_HEIGHT   64
#define VALVE_LED_PIN   10 // Pino para o LED que simula a válvula

// ==============================================================
// ----------------- Parâmetros da Aplicação --------------------
static const uint32_t PUBLISH_INTERVAL_MS = 5000UL; // Publicar a cada 3 segundos
static const uint32_t RECONNECT_INTERVAL_MS = 10000UL;
#define MQTT_KEEPALIVE 60
#define MQTT_CONTROL_TOPIC "esp32/temp/control"

// Configurações de NTP para fuso horário de São Paulo (BRT, GMT-3)
static const char* NTP_SERVER = "pool.ntp.org";
static const long  GMT_OFFSET_SEC = -3L * 3600L;
static const int   DAYLIGHT_OFFSET_SEC = 0;

// ==============================================================
// -------------- Variáveis Globais e Objetos -------------------
static QueueHandle_t    g_publishQueue = nullptr;
static QueueHandle_t    g_valveQueue = nullptr; // Fila para comandos da válvula
static volatile bool    g_ntpReady = false;

static Adafruit_SSD1306 g_display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
static Adafruit_AHTX0   g_aht;
static WiFiClientSecure g_wifiClient;
static PubSubClient     g_mqtt(g_wifiClient);

typedef struct {
  int     id;
  float   temperature;
  time_t  timestamp;
  char    datetime_br[25];
} sensor_message_t;

enum SystemState { STATE_BOOT, STATE_WIFI_CONNECT, STATE_NTP_SYNC, STATE_MQTT_CONNECT, STATE_OPERATIONAL, STATE_DISCONNECTED };
static SystemState g_currentState = STATE_BOOT;
static char g_displayStatus[20] = "Iniciando...";

// Protótipo da função de callback
void mqttCallback(char* topic, byte* payload, unsigned int length);

// ==============================================================
// -------------------- Funções Utilitárias ---------------------
static void updateDisplay(const sensor_message_t* msg) {
  g_display.clearDisplay();
  g_display.setTextSize(1);
  g_display.setTextColor(SSD1306_WHITE);

  g_display.setCursor(0, 0);
  g_display.print(F("Status: "));
  g_display.print(g_displayStatus);

  g_display.setTextSize(2);
  g_display.setCursor(0, 16);
  if (msg) g_display.print(msg->temperature, 1);
  else g_display.print(F("--.-"));
  g_display.print((char)247);
  g_display.print(F("C"));

  g_display.setTextSize(1);
  g_display.setCursor(0, 48);
  if (msg && g_ntpReady) g_display.print(msg->datetime_br);
  else g_display.print("Aguardando hora...");
  
  g_display.display();
}

// ==============================================================
// ----------------- Funções AWS IoT e MQTT ---------------------
static bool connectAWSIoT() {
  Serial.println("[MQTT] A configurar cliente...");
  g_wifiClient.setCACert(AWS_CERT_CA);
  g_wifiClient.setCertificate(AWS_CERT_CRT);
  g_wifiClient.setPrivateKey(AWS_CERT_PRIVATE);
  g_mqtt.setServer(AWS_IOT_ENDPOINT, 8883);
  g_mqtt.setCallback(mqttCallback); // Define a função de callback
  g_mqtt.setKeepAlive(MQTT_KEEPALIVE);

  char clientId[64];
  snprintf(clientId, sizeof(clientId), "%s-%s", THINGNAME, WiFi.macAddress().c_str());

  Serial.printf("[MQTT] A tentar ligar como '%s'...\n", clientId);
  if (g_mqtt.connect(clientId)) {
    Serial.println("[MQTT] Ligado com sucesso!");
    // Subscreve o tópico de controlo após a ligação
    g_mqtt.subscribe(MQTT_CONTROL_TOPIC);
    Serial.printf("[MQTT] Subscrito no tópico: %s\n", MQTT_CONTROL_TOPIC);
    return true;
  }
  Serial.printf("[MQTT] Falha na ligação, rc=%d.\n", g_mqtt.state());
  return false;
}

static void publishToAWS(const sensor_message_t& msg) {
  StaticJsonDocument<300> doc;
  doc["thingId"] = THINGNAME;
  doc["messageId"] = msg.id;
  doc["timestamp"] = msg.timestamp;
  doc["datetime_br"] = msg.datetime_br;
  JsonObject readings = doc.createNestedObject("readings");
  readings["temperature"] = msg.temperature;

  char payload[300];
  serializeJson(doc, payload, sizeof(payload));

  if (g_mqtt.publish(AWS_IOT_PUBLISH_TOPIC, payload)) {
    Serial.print("[MQTT] Publicado: ");
    Serial.println(payload);
  } else {
    Serial.println("[MQTT] Falha ao publicar.");
    g_currentState = STATE_DISCONNECTED;
  }
}

// Função de callback para mensagens MQTT recebidas
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.printf("[MQTT Rx] Mensagem recebida no tópico: %s\n", topic);

  StaticJsonDocument<128> doc;
  DeserializationError error = deserializeJson(doc, payload, length);

  if (error) {
    Serial.print(F("deserializeJson() falhou: "));
    Serial.println(error.c_str());
    return;
  }

  const char* command = doc["command"];
  if (command && strcmp(command, "open_valve") == 0) {
    uint32_t duration_seconds = doc["duration_seconds"];
    if (duration_seconds > 0) {
      // Envia a duração para a tarefa da válvula através da fila
      xQueueSend(g_valveQueue, &duration_seconds, pdMS_TO_TICKS(100));
    }
  }
}

// ==============================================================
// ---------------------- Tarefas do FreeRTOS -------------------

// Nova tarefa para controlar a válvula (LED) de forma não-bloqueante
void taskValveControl(void* pvParameters) {
    uint32_t duration_seconds = 0;
    for (;;) {
        // Espera indefinidamente até que uma duração seja recebida na fila
        if (xQueueReceive(g_valveQueue, &duration_seconds, portMAX_DELAY) == pdPASS) {
            Serial.printf("[Valve] Comando recebido: Ligar por %u segundos.\n", duration_seconds);
            digitalWrite(VALVE_LED_PIN, HIGH);
            vTaskDelay(pdMS_TO_TICKS(duration_seconds * 1000));
            digitalWrite(VALVE_LED_PIN, LOW);
            Serial.println("[Valve] Válvula desligada.");
        }
    }
}

void taskConnectionManager(void* pvParameters) {
  sensor_message_t msgToPublish;
  uint32_t lastReconnectAttempt = 0;
  g_currentState = STATE_WIFI_CONNECT;

  for (;;) {
    switch (g_currentState) {
      case STATE_WIFI_CONNECT:
        strcpy(g_displayStatus, "A ligar WiFi...");
        WiFi.mode(WIFI_STA);
        WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
        if (WiFi.waitForConnectResult(15000) == WL_CONNECTED) {
          Serial.printf("[WiFi] Ligado! IP: %s\n", WiFi.localIP().toString().c_str());
          g_currentState = STATE_NTP_SYNC;
        } else {
          g_currentState = STATE_DISCONNECTED;
        }
        break;

      case STATE_NTP_SYNC:
        strcpy(g_displayStatus, "A sincronizar hora...");
        configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER);
        struct tm timeinfo;
        if (getLocalTime(&timeinfo, 10000)) {
          g_ntpReady = true;
          g_currentState = STATE_MQTT_CONNECT;
        } else {
          g_currentState = STATE_DISCONNECTED;
        }
        break;

      case STATE_MQTT_CONNECT:
        strcpy(g_displayStatus, "A ligar MQTT...");
        if (connectAWSIoT()) {
          g_currentState = STATE_OPERATIONAL;
          strcpy(g_displayStatus, "Operacional");
        } else {
          g_currentState = STATE_DISCONNECTED;
        }
        break;

      case STATE_OPERATIONAL:
        if (WiFi.status() != WL_CONNECTED || !g_mqtt.connected()) {
          g_currentState = STATE_DISCONNECTED;
          break;
        }
        g_mqtt.loop(); // Essencial para receber mensagens
        if (xQueueReceive(g_publishQueue, &msgToPublish, 0) == pdPASS) {
          publishToAWS(msgToPublish);
          updateDisplay(&msgToPublish);
        }
        break;

      case STATE_DISCONNECTED:
        strcpy(g_displayStatus, "Desligado");
        if (millis() - lastReconnectAttempt > RECONNECT_INTERVAL_MS) {
          lastReconnectAttempt = millis();
          g_currentState = STATE_WIFI_CONNECT;
        }
        break;
        
      default:
        g_currentState = STATE_WIFI_CONNECT;
        break;
    }
    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

void taskSensorReader(void* pvParameters) {
  while (!g_ntpReady) vTaskDelay(pdMS_TO_TICKS(500));
  int messageIdCounter = 1000;
  for (;;) {
    sensors_event_t humidity, tempEvent;
    if (g_aht.getEvent(&humidity, &tempEvent)) {
      sensor_message_t reading = {};
      reading.id = messageIdCounter++;
      reading.temperature = roundf(tempEvent.temperature * 10.0) / 10.0;
      reading.timestamp = time(nullptr);
      struct tm timeinfo;
      localtime_r(&reading.timestamp, &timeinfo);
      strftime(reading.datetime_br, sizeof(reading.datetime_br), "%d/%m/%Y %H:%M:%S", &timeinfo);
      xQueueSend(g_publishQueue, &reading, 0);
    } else {
      Serial.println("[Sensor] Erro ao ler o sensor AHT10!");
    }
    vTaskDelay(pdMS_TO_TICKS(PUBLISH_INTERVAL_MS));
  }
}

// ==============================================================
// -------------------- Funções setup() e loop() ----------------

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n==================================================");
  Serial.println("   ESP32-C3 AWS IoT - Controlo de Válvula       ");
  Serial.println("==================================================");

  pinMode(VALVE_LED_PIN, OUTPUT);
  digitalWrite(VALVE_LED_PIN, LOW); // Garante que a válvula comece desligada

  Wire.begin(SDA_PIN, SCL_PIN);

  if (!g_display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) Serial.println("[OLED] Falha ao inicializar");
  else Serial.println("[OLED] Display inicializado.");
  
  if (!g_aht.begin()) Serial.println("[AHT10] Sensor não encontrado!");
  else Serial.println("[AHT10] Sensor inicializado.");

  g_publishQueue = xQueueCreate(5, sizeof(sensor_message_t));
  g_valveQueue = xQueueCreate(1, sizeof(uint32_t));

  xTaskCreate(taskConnectionManager, "ConnManager_Task", 8192, NULL, 2, NULL);
  xTaskCreate(taskSensorReader, "SensorReader_Task", 4096, NULL, 1, NULL);
  xTaskCreate(taskValveControl, "ValveControl_Task", 2048, NULL, 1, NULL);
}

void loop() {
  vTaskDelay(portMAX_DELAY);
}