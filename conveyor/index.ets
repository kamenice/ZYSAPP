/*
 * Smart Conveyor Belt System - ArkTS UI
 *
 * This UI interfaces with the code9 Smart Conveyor Belt System
 * via MQTT protocol over WiFi.
 *
 * WiFi: zys / 12345678
 * Server IP: 192.168.43.230
 * MQTT Port: 1883
 * MQTT Topic: conveyor
 *
 * Note: Requires @ohos/mqtt package. Install with: ohpm install @ohos/mqtt
 * And add INTERNET permission in module.json5
 */

import { MqttAsync, MqttConnectOptions, MqttSubscribeOptions, MqttResponse, MqttPublishOptions, MqttAsyncClient } from '@ohos/mqtt';

// MQTT Configuration
const MQTT_HOST: string = '192.168.43.230';
const MQTT_PORT: number = 1883;
const MQTT_TOPIC: string = 'conveyor';
const MQTT_CLIENT_ID: string = 'arkts_conveyor_app';

// WiFi Configuration
const WIFI_SSID: string = 'zys';
const WIFI_PASSWORD: string = '12345678';

// Conveyor Belt Status Data from MQTT
interface MqttData {
  hasItem?: number;       // 0 = No item, 1 = Item detected
  temperature?: number;   // Temperature in Celsius
  motorState?: number;    // 0 = Stopped, 1 = Running
}

// Message callback type
type MessageCallback = (payload: string) => void;

// MQTT Utility Class
class MQTTUtil {
  private mqttClient: MqttAsyncClient | null = null;
  private isConnected: boolean = false;
  private messageCallback: MessageCallback | null = null;

  connect(onMessage: MessageCallback): void {
    this.messageCallback = onMessage;

    // Create MQTT client
    this.mqttClient = MqttAsync.createMqtt({
      url: `tcp://${MQTT_HOST}:${MQTT_PORT}`,
      clientId: MQTT_CLIENT_ID,
      persistenceType: 1
    });

    // Set up message arrival callback
    this.mqttClient.messageArrived((err: Error, data: MqttResponse) => {
      if (!err && data && this.messageCallback) {
        // Get payload from response
        const payload = data.message?.payload ?? '';
        this.messageCallback(String(payload));
      }
    });

    // Set up connection lost callback
    this.mqttClient.connectLost((err: Error, data: MqttResponse) => {
      console.info('[MQTT] Connection lost');
      this.isConnected = false;
    });

    // Connect to broker
    const connectOptions: MqttConnectOptions = {
      cleanSession: true,
      connectTimeout: 30,
      keepAliveInterval: 60,
      userName: 'hi3861',
      password: 'password'
    };

    this.mqttClient.connect(connectOptions)
      .then(() => {
        console.info('[MQTT] Connected to broker');
        this.isConnected = true;
        this.subscribe();
      })
      .catch((err: Error) => {
        console.error('[MQTT] Connection failed: ' + err.message);
        this.isConnected = false;
      });
  }

  private subscribe(): void {
    if (!this.mqttClient) {
      return;
    }

    const subscribeOptions: MqttSubscribeOptions = {
      topic: MQTT_TOPIC,
      qos: 0
    };

    this.mqttClient.subscribe(subscribeOptions)
      .then(() => {
        console.info('[MQTT] Subscribed to topic: ' + MQTT_TOPIC);
      })
      .catch((err: Error) => {
        console.error('[MQTT] Subscribe failed: ' + err.message);
      });
  }

  publish(message: string): void {
    if (!this.mqttClient || !this.isConnected) {
      console.error('[MQTT] Cannot publish: not connected');
      return;
    }

    const publishOptions: MqttPublishOptions = {
      topic: MQTT_TOPIC,
      qos: 0,
      payload: message
    };

    this.mqttClient.publish(publishOptions)
      .then(() => {
        console.info('[MQTT] Message published');
      })
      .catch((err: Error) => {
        console.error('[MQTT] Publish failed: ' + err.message);
      });
  }

  disconnect(): void {
    if (this.mqttClient) {
      this.mqttClient.disconnect()
        .then(() => {
          console.info('[MQTT] Disconnected');
          this.isConnected = false;
        })
        .catch((err: Error) => {
          console.error('[MQTT] Disconnect error: ' + err.message);
        });
      this.mqttClient = null;
    }
  }

  getConnectionStatus(): boolean {
    return this.isConnected;
  }
}

@Entry
@Component
struct Index {
  // State variables for UI display
  @State hasItem: boolean = false;
  @State temperature: number = 0.0;
  @State motorRunning: boolean = false;
  @State overTemp: boolean = false;
  @State wifiStatus: number = 0;  // 0 = disconnected, 1 = connected
  @State lastUpdateTime: string = '--:--:--';

  // MQTT utility instance
  private mqttUtil: MQTTUtil = new MQTTUtil();

  // Temperature threshold (same as code9: 30°C)
  private readonly TEMP_THRESHOLD: number = 30.0;

  aboutToAppear(): void {
    // Initialize with mock data
    this.initMockData();

    // Connect to MQTT and receive real-time data
    this.mqttUtil.connect((payload: string) => {
      this.handleMqttMessage(payload);
    });
  }

  aboutToDisappear(): void {
    this.mqttUtil.disconnect();
  }

  initMockData(): void {
    // Initialize with default values
    this.hasItem = false;
    this.temperature = 25.0;
    this.motorRunning = false;
    this.overTemp = false;
    this.wifiStatus = 0;
  }

  handleMqttMessage(payload: string): void {
    try {
      const receivedData: MqttData = JSON.parse(payload);

      // Update sensor data
      this.hasItem = (receivedData.hasItem ?? 0) === 1;
      this.temperature = receivedData.temperature ?? this.temperature;
      this.motorRunning = (receivedData.motorState ?? 0) === 1;
      this.overTemp = this.temperature > this.TEMP_THRESHOLD;

      // Update connection status and timestamp
      this.wifiStatus = 1;
      this.lastUpdateTime = new Date().toLocaleTimeString();

      console.info(`[MQTT] Data received - Item: ${this.hasItem}, Temp: ${this.temperature}, Motor: ${this.motorRunning}`);
    } catch (e) {
      console.error('[MQTT] Parse error:', e);
    }
  }

  handleReconnect(): void {
    this.wifiStatus = 0;
    this.mqttUtil.disconnect();
    setTimeout(() => {
      this.mqttUtil.connect((payload: string) => {
        this.handleMqttMessage(payload);
      });
    }, 1000);
  }

  build() {
    Column() {
      // Top Title Bar
      Row() {
        Text('📦')
          .fontSize(28)
        Text('智能传送带监控系统')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ left: 10 })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#2196F3')
      .justifyContent(FlexAlign.Start)

      // Content Area
      Scroll() {
        Column({ space: 12 }) {
          // Connection Status Card
          Row() {
            Text('●')
              .fontSize(16)
              .fontColor(this.wifiStatus === 1 ? '#4CAF50' : '#F44336')
              .margin({ right: 8 })
            Text(this.wifiStatus === 1 ? '已连接' : '未连接')
              .fontSize(16)
              .fontColor(this.wifiStatus === 1 ? '#4CAF50' : '#F44336')
            Blank()
            Text(`更新: ${this.lastUpdateTime}`)
              .fontSize(12)
              .fontColor('#999999')
          }
          .width('100%')
          .padding(12)
          .backgroundColor(Color.White)
          .borderRadius(8)

          // Status Cards
          Column({ space: 10 }) {
            // Item Detection Card
            this.StatusCard(
              '📦',
              '物品检测',
              this.hasItem ? '有物品' : '无物品',
              this.hasItem ? '#4CAF50' : '#9E9E9E'
            )

            // Temperature Card
            this.StatusCard(
              '🌡️',
              '当前温度',
              `${this.temperature.toFixed(1)}°C`,
              this.overTemp ? '#F44336' : '#2196F3'
            )

            // Motor Status Card
            this.StatusCard(
              '⚙️',
              '电机状态',
              this.motorRunning ? '运行中' : '已停止',
              this.motorRunning ? '#4CAF50' : '#FF9800'
            )

            // Alarm Status Card
            this.StatusCard(
              '🔔',
              '报警状态',
              this.overTemp ? '温度过高!' : '正常',
              this.overTemp ? '#F44336' : '#4CAF50'
            )
          }
          .width('100%')

          // Connection Info Card
          Column({ space: 8 }) {
            Text('连接信息')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')

            Row() {
              Text('WiFi:')
                .fontSize(14)
                .fontColor('#666666')
              Blank()
              Text(WIFI_SSID)
                .fontSize(14)
                .fontColor('#333333')
            }
            .width('100%')

            Row() {
              Text('服务器:')
                .fontSize(14)
                .fontColor('#666666')
              Blank()
              Text(`${MQTT_HOST}:${MQTT_PORT}`)
                .fontSize(14)
                .fontColor('#333333')
            }
            .width('100%')

            Row() {
              Text('主题:')
                .fontSize(14)
                .fontColor('#666666')
              Blank()
              Text(MQTT_TOPIC)
                .fontSize(14)
                .fontColor('#333333')
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(8)

          // Reconnect Button
          Button('重新连接')
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor(this.wifiStatus === 1 ? '#9E9E9E' : '#2196F3')
            .borderRadius(8)
            .onClick(() => {
              this.handleReconnect();
            })
        }
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  // Reusable Status Card Component
  @Builder
  StatusCard(icon: string, title: string, value: string, color: string) {
    Row() {
      Text(icon)
        .fontSize(32)
        .margin({ right: 12 })

      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ bottom: 4 })

        Text(value)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(color)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text('●')
        .fontSize(20)
        .fontColor(color)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(8)
  }
}