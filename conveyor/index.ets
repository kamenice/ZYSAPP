/*
 * Copyright (c) 2020 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Smart Conveyor Belt System - Mobile App UI
 *
 * This ArkTS interface connects to the Hi3861 conveyor belt system via MQTT.
 *
 * WiFi Configuration:
 * - SSID: zys
 * - Password: 12345678
 *
 * MQTT Configuration:
 * - Server IP: 192.168.43.230 (PC connected to WiFi)
 * - Port: 1883
 * - Topic: conveyor
 *
 * Data Format (JSON):
 * {"hasItem":0/1, "temperature":float, "motorState":0/1}
 */

import mqtt from '@ohos.mqtt';
import wifi from '@ohos.wifi';
import util from '@ohos.util';

// MQTT Configuration
const MQTT_HOST: string = '192.168.43.230';
const MQTT_PORT: number = 1883;
const MQTT_TOPIC: string = 'conveyor';
const MQTT_CLIENT_ID: string = 'arkts_conveyor_app';

// WiFi Configuration (as per requirements)
// Note: These credentials are specified in the project requirements
// In production, consider using secure storage or configuration files
const WIFI_SSID: string = 'zys';
const WIFI_PASSWORD: string = '12345678';

// MQTT Authentication (matching hi3861 device credentials)
const MQTT_USERNAME: string = 'hi3861';
const MQTT_PASSWORD: string = 'password';

// Conveyor status data interface
interface ConveyorStatus {
  hasItem: number;
  temperature: number;
  motorState: number;
}

@Entry
@Component
struct ConveyorBeltApp {
  // State variables for sensor data
  @State hasItem: number = 0;
  @State temperature: number = 0.0;
  @State motorState: number = 0;

  // Connection status
  @State wifiConnected: boolean = false;
  @State mqttConnected: boolean = false;
  @State connectionStatus: string = 'Disconnected';

  // MQTT client
  private mqttClient: mqtt.MqttAsyncClient | null = null;

  aboutToAppear() {
    this.connectToWiFi();
  }

  aboutToDisappear() {
    this.disconnectMqtt();
  }

  // Connect to WiFi with proper state handling
  async connectToWiFi() {
    this.connectionStatus = 'Connecting to WiFi...';
    this.wifiConnected = false;

    try {
      // Check if WiFi is enabled
      let isActive = wifi.isWifiActive();
      if (!isActive) {
        await wifi.enableWifi();
        // Wait for WiFi to be fully enabled
        await this.waitForCondition(() => wifi.isWifiActive(), 5000);
      }

      // Configure WiFi connection
      let config: wifi.WifiDeviceConfig = {
        ssid: WIFI_SSID,
        preSharedKey: WIFI_PASSWORD,
        securityType: wifi.WifiSecurityType.WIFI_SEC_TYPE_PSK
      };

      // Connect to WiFi
      await wifi.connectToDevice(config);

      // Wait for connection to be established
      await this.waitForCondition(() => wifi.isConnected(), 10000);

      this.wifiConnected = true;
      this.connectionStatus = 'WiFi Connected, connecting MQTT...';

      // Connect to MQTT after WiFi connection confirmed
      this.connectMqtt();
    } catch (error) {
      this.wifiConnected = false;
      this.connectionStatus = 'WiFi connection failed';
      console.error('WiFi connection error:', JSON.stringify(error));
    }
  }

  // Helper function to wait for a condition with timeout
  private waitForCondition(condition: () => boolean, timeoutMs: number): Promise<void> {
    return new Promise((resolve, reject) => {
      const checkInterval = 500;
      let elapsed = 0;

      const check = () => {
        if (condition()) {
          resolve();
        } else if (elapsed >= timeoutMs) {
          reject(new Error('Timeout waiting for condition'));
        } else {
          elapsed += checkInterval;
          setTimeout(check, checkInterval);
        }
      };

      check();
    });
  }

  // Connect to MQTT broker
  async connectMqtt() {
    try {
      let mqttUrl = `tcp://${MQTT_HOST}:${MQTT_PORT}`;

      let options: mqtt.MqttConnectOptions = {
        clientId: MQTT_CLIENT_ID,
        connectTimeout: 30,
        keepAliveInterval: 60,
        cleanSession: true,
        username: MQTT_USERNAME,
        password: MQTT_PASSWORD
      };

      this.mqttClient = mqtt.createMqttAsyncClient(mqttUrl, options);

      // Set up message callback
      this.mqttClient.on('message', (topic: string, payload: ArrayBuffer) => {
        this.handleMqttMessage(topic, payload);
      });

      // Set up connection callback
      this.mqttClient.on('connect', () => {
        this.mqttConnected = true;
        this.connectionStatus = 'Connected';
        this.subscribeTopic();
      });

      // Set up disconnect callback
      this.mqttClient.on('disconnect', () => {
        this.mqttConnected = false;
        this.connectionStatus = 'Disconnected';
      });

      // Connect to broker
      await this.mqttClient.connect();
    } catch (error) {
      this.connectionStatus = 'MQTT connection failed';
      console.error('MQTT connection error:', JSON.stringify(error));
    }
  }

  // Subscribe to conveyor topic
  async subscribeTopic() {
    if (this.mqttClient) {
      try {
        await this.mqttClient.subscribe(MQTT_TOPIC, mqtt.QoS.AtLeastOnce);
        console.info('Subscribed to topic:', MQTT_TOPIC);
      } catch (error) {
        console.error('Subscribe error:', JSON.stringify(error));
      }
    }
  }

  // Handle incoming MQTT messages
  handleMqttMessage(topic: string, payload: ArrayBuffer) {
    if (topic === MQTT_TOPIC) {
      try {
        let decoder = new util.TextDecoder('utf-8');
        let message = decoder.decode(new Uint8Array(payload));
        let data: ConveyorStatus = JSON.parse(message);

        // Update state with received data
        this.hasItem = data.hasItem;
        this.temperature = data.temperature;
        this.motorState = data.motorState;
      } catch (error) {
        console.error('Message parse error:', JSON.stringify(error));
      }
    }
  }

  // Disconnect MQTT
  disconnectMqtt() {
    if (this.mqttClient) {
      this.mqttClient.disconnect();
      this.mqttClient = null;
    }
  }

  // Get item status text
  getItemStatusText(): string {
    return this.hasItem === 1 ? 'Detected' : 'None';
  }

  // Get item status color
  getItemStatusColor(): string {
    return this.hasItem === 1 ? '#4CAF50' : '#9E9E9E';
  }

  // Get motor status text
  getMotorStatusText(): string {
    return this.motorState === 1 ? 'Running' : 'Stopped';
  }

  // Get motor status color
  getMotorStatusColor(): string {
    return this.motorState === 1 ? '#2196F3' : '#9E9E9E';
  }

  // Get temperature status color
  getTemperatureColor(): string {
    if (this.temperature > 30) {
      return '#F44336'; // Red for high temperature
    } else if (this.temperature > 25) {
      return '#FF9800'; // Orange for warm
    }
    return '#4CAF50'; // Green for normal
  }

  // Get connection status color
  getConnectionColor(): string {
    if (this.mqttConnected) {
      return '#4CAF50';
    } else if (this.wifiConnected) {
      return '#FF9800';
    }
    return '#F44336';
  }

  build() {
    Column() {
      // Title
      Text('Smart Conveyor Belt')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .margin({ top: 40, bottom: 20 })

      // Connection status card
      Column() {
        Row() {
          Circle()
            .width(12)
            .height(12)
            .fill(this.getConnectionColor())
            .margin({ right: 8 })

          Text(this.connectionStatus)
            .fontSize(14)
            .fontColor('#666666')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Text(`WiFi: ${WIFI_SSID} | Server: ${MQTT_HOST}`)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 8 })
      }
      .width('90%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .shadow({
        radius: 8,
        color: '#1A000000',
        offsetX: 0,
        offsetY: 2
      })

      // Status cards container
      Column() {
        // Item detection card
        Row() {
          Column() {
            Text('Item Status')
              .fontSize(14)
              .fontColor('#666666')
            Text(this.getItemStatusText())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getItemStatusColor())
              .margin({ top: 8 })
          }
          .width('50%')
          .alignItems(HorizontalAlign.Center)

          Divider()
            .vertical(true)
            .height(60)
            .color('#E0E0E0')

          // Motor status
          Column() {
            Text('Motor')
              .fontSize(14)
              .fontColor('#666666')
            Text(this.getMotorStatusText())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getMotorStatusColor())
              .margin({ top: 8 })
          }
          .width('50%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .padding(20)
      }
      .width('90%')
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ top: 20 })
      .shadow({
        radius: 8,
        color: '#1A000000',
        offsetX: 0,
        offsetY: 2
      })

      // Temperature card
      Column() {
        Text('Temperature')
          .fontSize(14)
          .fontColor('#666666')

        Row() {
          Text(this.temperature.toFixed(1))
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getTemperatureColor())

          Text('°C')
            .fontSize(24)
            .fontColor(this.getTemperatureColor())
            .margin({ left: 4, top: 8 })
        }
        .margin({ top: 12 })

        // Temperature warning
        if (this.temperature > 30) {
          Row() {
            Text('⚠️ High Temperature Alert!')
              .fontSize(14)
              .fontColor('#F44336')
          }
          .margin({ top: 12 })
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#FFEBEE')
          .borderRadius(16)
        }

        // Temperature bar
        Progress({ value: Math.min(this.temperature, 50), total: 50, type: ProgressType.Linear })
          .width('80%')
          .height(8)
          .color(this.getTemperatureColor())
          .backgroundColor('#E0E0E0')
          .margin({ top: 16 })

        Row() {
          Text('0°C')
            .fontSize(10)
            .fontColor('#999999')
          Blank()
          Text('30°C')
            .fontSize(10)
            .fontColor('#F44336')
          Blank()
          Text('50°C')
            .fontSize(10)
            .fontColor('#999999')
        }
        .width('80%')
        .margin({ top: 4 })
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ top: 20 })
      .shadow({
        radius: 8,
        color: '#1A000000',
        offsetX: 0,
        offsetY: 2
      })

      // System info card
      Column() {
        Text('System Information')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ bottom: 12 })

        Row() {
          Text('HX711 Pressure Sensor')
            .fontSize(12)
            .fontColor('#333333')
          Blank()
          Text(this.hasItem === 1 ? '●' : '○')
            .fontSize(16)
            .fontColor(this.hasItem === 1 ? '#4CAF50' : '#9E9E9E')
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })

        Row() {
          Text('DHT11 Temperature Sensor')
            .fontSize(12)
            .fontColor('#333333')
          Blank()
          Text(this.temperature > 0 ? '●' : '○')
            .fontSize(16)
            .fontColor(this.temperature > 0 ? '#4CAF50' : '#9E9E9E')
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })

        Row() {
          Text('TB6612 Motor Driver')
            .fontSize(12)
            .fontColor('#333333')
          Blank()
          Text(this.motorState === 1 ? '●' : '○')
            .fontSize(16)
            .fontColor(this.motorState === 1 ? '#2196F3' : '#9E9E9E')
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
      }
      .width('90%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ top: 20 })
      .shadow({
        radius: 8,
        color: '#1A000000',
        offsetX: 0,
        offsetY: 2
      })

      // Reconnect button
      Button('Reconnect')
        .width('90%')
        .height(48)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor(this.mqttConnected ? '#9E9E9E' : '#2196F3')
        .borderRadius(24)
        .margin({ top: 20, bottom: 40 })
        .enabled(!this.mqttConnected)
        .onClick(() => {
          this.connectToWiFi();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
