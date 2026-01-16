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

import { MqttAsync, MqttConnectOptions, MqttSubscribeOptions, MqttClient } from '@ohos/mqtt';

// MQTT Configuration
const MQTT_HOST: string = '192.168.43.230';
const MQTT_PORT: number = 1883;
const MQTT_TOPIC: string = 'conveyor';
const MQTT_CLIENT_ID: string = 'arkts_conveyor_app';

// WiFi Configuration
const WIFI_SSID: string = 'zys';
const WIFI_PASSWORD: string = '12345678';

// Conveyor Belt Status Data
interface ConveyorStatus {
  hasItem: number;       // 0 = No item, 1 = Item detected
  temperature: number;   // Temperature in Celsius
  motorState: number;    // 0 = Stopped, 1 = Running
}

@Entry
@Component
struct Index {
  // State variables for UI display
  @State hasItem: boolean = false;
  @State temperature: number = 0.0;
  @State motorRunning: boolean = false;
  @State overTemp: boolean = false;
  @State isConnected: boolean = false;
  @State connectionStatus: string = '未连接';
  @State lastUpdate: string = '--:--:--';

  // MQTT client instance
  private mqttClient: MqttClient | null = null;

  // Temperature threshold (same as code9: 30°C)
  private readonly TEMP_THRESHOLD: number = 30.0;

  aboutToAppear(): void {
    this.connectMqtt();
  }

  aboutToDisappear(): void {
    this.disconnectMqtt();
  }

  // Connect to MQTT broker
  private connectMqtt(): void {
    this.connectionStatus = '连接中...';

    // Create MQTT client
    this.mqttClient = MqttAsync.createMqtt({
      url: `tcp://${MQTT_HOST}:${MQTT_PORT}`,
      clientId: MQTT_CLIENT_ID,
      persistenceType: 1
    });

    // Set up message arrival callback
    this.mqttClient.messageArrived((err: Error | null, data: object) => {
      if (err) {
        console.error('[MQTT] Message error: ' + err.message);
        return;
      }
      const msgData = data as { topic: string; payload: string };
      this.handleMessage(msgData.topic, msgData.payload);
    });

    // Set up connection lost callback
    this.mqttClient.connectLost((err: Error | null, data: object) => {
      console.info('[MQTT] Connection lost');
      this.isConnected = false;
      this.connectionStatus = '连接断开';
    });

    // Connect to broker
    const connectOptions: MqttConnectOptions = {
      cleanStart: true,
      connectTimeout: 30,
      keepAliveInterval: 60,
      userName: 'hi3861',
      password: 'password'
    };

    this.mqttClient.connect(connectOptions)
      .then(() => {
        console.info('[MQTT] Connected to broker');
        this.isConnected = true;
        this.connectionStatus = '已连接';
        this.subscribeToTopic();
      })
      .catch((err: Error) => {
        console.error('[MQTT] Connection failed: ' + err.message);
        this.isConnected = false;
        this.connectionStatus = '连接失败';
      });
  }

  // Subscribe to conveyor topic
  private subscribeToTopic(): void {
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

  // Handle incoming MQTT message
  private handleMessage(topic: string, payload: string): void {
    if (topic === MQTT_TOPIC) {
      try {
        const data: ConveyorStatus = JSON.parse(payload);

        // Update UI state
        this.hasItem = data.hasItem === 1;
        this.temperature = data.temperature;
        this.motorRunning = data.motorState === 1;
        this.overTemp = data.temperature > this.TEMP_THRESHOLD;

        // Update timestamp
        const now = new Date();
        const hours = now.getHours().toString().padStart(2, '0');
        const minutes = now.getMinutes().toString().padStart(2, '0');
        const seconds = now.getSeconds().toString().padStart(2, '0');
        this.lastUpdate = `${hours}:${minutes}:${seconds}`;

        console.info(`[MQTT] Data received - Item: ${this.hasItem}, Temp: ${this.temperature}, Motor: ${this.motorRunning}`);
      } catch (error) {
        console.error('[MQTT] Parse error: ' + error);
      }
    }
  }

  // Disconnect from MQTT broker
  private disconnectMqtt(): void {
    if (this.mqttClient) {
      const client = this.mqttClient;
      this.mqttClient = null;
      client.disconnect()
        .then(() => {
          console.info('[MQTT] Disconnected');
        })
        .catch((err: Error) => {
          console.error('[MQTT] Disconnect error: ' + err.message);
        });
    }
  }

  // Reconnect to MQTT broker
  private reconnect(): void {
    this.disconnectMqtt();
    this.connectionStatus = '重新连接中...';
    this.isConnected = false;
    setTimeout(() => {
      this.connectMqtt();
    }, 1000);
  }

  build() {
    Column() {
      // Title
      Text('智能传送带监控系统')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 20, bottom: 10 })

      // Connection Status
      Row() {
        Text('●')
          .fontSize(16)
          .fontColor(this.isConnected ? '#4CAF50' : '#F44336')
          .margin({ right: 8 })
        Text(this.connectionStatus)
          .fontSize(16)
          .fontColor(this.isConnected ? '#4CAF50' : '#F44336')
      }
      .margin({ bottom: 20 })

      // Status Cards Container
      Column() {
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
      .padding(16)

      // Last Update Time
      Text(`最后更新: ${this.lastUpdate}`)
        .fontSize(14)
        .fontColor('#666666')
        .margin({ top: 16 })

      // Connection Info
      Column() {
        Text('连接信息')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .margin({ bottom: 8 })

        Text(`WiFi: ${WIFI_SSID}`)
          .fontSize(14)
          .fontColor('#666666')

        Text(`服务器: ${MQTT_HOST}:${MQTT_PORT}`)
          .fontSize(14)
          .fontColor('#666666')

        Text(`主题: ${MQTT_TOPIC}`)
          .fontSize(14)
          .fontColor('#666666')
      }
      .width('90%')
      .padding(16)
      .backgroundColor('#F5F5F5')
      .borderRadius(12)
      .margin({ top: 20 })

      // Reconnect Button
      Button('重新连接')
        .width('80%')
        .height(48)
        .fontSize(18)
        .fontColor('#FFFFFF')
        .backgroundColor(this.isConnected ? '#9E9E9E' : '#2196F3')
        .borderRadius(24)
        .margin({ top: 20, bottom: 20 })
        .onClick(() => {
          this.reconnect();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  // Reusable Status Card Component
  @Builder
  StatusCard(icon: string, title: string, value: string, color: string) {
    Row() {
      Text(icon)
        .fontSize(32)
        .margin({ right: 16 })

      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ bottom: 4 })

        Text(value)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor(color)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text('●')
        .fontSize(16)
        .fontColor(color)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FAFAFA')
    .borderRadius(12)
    .margin({ bottom: 12 })
  }
}