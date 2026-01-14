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

import mqtt from '@ohos/mqtt'

// MQTT配置 - 与wifi_mqtt.h保持一致，实际部署时应从配置文件读取
const MQTT_HOST: string = '192.168.43.230'
const MQTT_PORT: number = 1883
const MQTT_TOPIC_STATUS: string = 'conveyor/status'
const MQTT_TOPIC_CONTROL: string = 'conveyor/control'
const MQTT_TOPIC_ALERT: string = 'conveyor/alert'

// 传送带状态数据接口
interface ConveyorStatus {
  weight: number       // 重量 (克)
  temp: number         // 温度 (摄氏度)
  speed: number        // 速度 (RPM)
  running: number      // 运行状态 (0=停止, 1=运行)
  time: number         // 运行时间 (秒)
}

// 告警数据接口
interface AlertData {
  alert: string        // 告警类型
  value: number        // 告警值
}

@Entry
@Component
struct ConveyorMonitor {
  // 状态数据
  @State weight: number = 0
  @State temperature: number = 0
  @State speed: number = 0
  @State isRunning: boolean = false
  @State runTimeSeconds: number = 0

  // 告警状态
  @State isOverweight: boolean = false
  @State isOverheat: boolean = false
  @State isJammed: boolean = false
  @State lastAlert: string = ''

  // 连接状态
  @State isConnected: boolean = false
  @State connectionStatus: string = '未连接'

  // MQTT客户端
  private mqttClient: mqtt.MqttClient | null = null

  aboutToAppear(): void {
    this.connectMqtt()
  }

  aboutToDisappear(): void {
    this.disconnectMqtt()
  }

  // 连接MQTT服务器
  connectMqtt(): void {
    try {
      // 凭证与wifi_mqtt.h保持一致，实际部署时应从安全存储读取
      const options: mqtt.MqttConnectOptions = {
        host: MQTT_HOST,
        port: MQTT_PORT,
        clientId: 'arkts_conveyor_monitor_' + Date.now(),
        username: 'conveyor',
        password: 'conveyor123',
        keepalive: 60
      }

      this.mqttClient = mqtt.createClient(options)

      this.mqttClient.on('connect', () => {
        this.isConnected = true
        this.connectionStatus = '已连接'
        // 订阅状态和告警主题
        this.mqttClient?.subscribe(MQTT_TOPIC_STATUS)
        this.mqttClient?.subscribe(MQTT_TOPIC_ALERT)
      })

      this.mqttClient.on('message', (topic: string, message: string) => {
        this.handleMessage(topic, message)
      })

      this.mqttClient.on('error', (error: Error) => {
        this.isConnected = false
        this.connectionStatus = '连接错误: ' + error.message
      })

      this.mqttClient.on('close', () => {
        this.isConnected = false
        this.connectionStatus = '连接已断开'
      })

      this.mqttClient.connect()
    } catch (error) {
      this.connectionStatus = '连接失败'
    }
  }

  // 断开MQTT连接
  disconnectMqtt(): void {
    if (this.mqttClient) {
      this.mqttClient.disconnect()
      this.mqttClient = null
    }
  }

  // 处理MQTT消息
  handleMessage(topic: string, message: string): void {
    try {
      if (topic === MQTT_TOPIC_STATUS) {
        const status: ConveyorStatus = JSON.parse(message)
        this.weight = status.weight
        this.temperature = status.temp
        this.speed = status.speed
        this.isRunning = status.running === 1
        this.runTimeSeconds = status.time
      } else if (topic === MQTT_TOPIC_ALERT) {
        const alert: AlertData = JSON.parse(message)
        this.handleAlert(alert)
      }
    } catch (error) {
      console.error('消息解析错误:', error)
    }
  }

  // 处理告警消息
  handleAlert(alert: AlertData): void {
    switch (alert.alert) {
      case 'overweight':
        this.isOverweight = true
        this.lastAlert = '超重告警: ' + alert.value.toFixed(1) + '克'
        break
      case 'overheat':
        this.isOverheat = true
        this.lastAlert = '过热告警: ' + alert.value.toFixed(1) + '°C'
        break
      case 'jam':
        this.isJammed = true
        this.lastAlert = '堵塞告警'
        break
    }
  }

  // 发送控制命令
  sendCommand(command: string): void {
    if (this.mqttClient && this.isConnected) {
      this.mqttClient.publish(MQTT_TOPIC_CONTROL, command)
    }
  }

  // 格式化运行时间
  formatTime(seconds: number): string {
    const mins: number = Math.floor(seconds / 60)
    const secs: number = seconds % 60
    return mins.toString().padStart(2, '0') + ':' + secs.toString().padStart(2, '0')
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('传送带智能监控系统')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height(60)
      .backgroundColor('#1976D2')
      .justifyContent(FlexAlign.Center)

      // 连接状态
      Row() {
        Circle()
          .width(12)
          .height(12)
          .fill(this.isConnected ? '#4CAF50' : '#F44336')
        Text(this.connectionStatus)
          .fontSize(14)
          .margin({ left: 8 })
          .fontColor(this.isConnected ? '#4CAF50' : '#F44336')
      }
      .width('100%')
      .padding(10)
      .justifyContent(FlexAlign.Center)

      // 数据显示区域
      Column() {
        // 运行状态
        Row() {
          Text('运行状态')
            .fontSize(16)
            .fontColor('#666666')
          Blank()
          Text(this.isRunning ? '运行中' : '已停止')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isRunning ? '#4CAF50' : '#F44336')
        }
        .width('100%')
        .padding(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .margin({ bottom: 10 })

        // 重量显示
        Row() {
          Text('当前重量')
            .fontSize(16)
            .fontColor('#666666')
          Blank()
          Text(this.weight.toFixed(1) + ' 克')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isOverweight ? '#F44336' : '#333333')
        }
        .width('100%')
        .padding(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .margin({ bottom: 10 })

        // 温度显示
        Row() {
          Text('当前温度')
            .fontSize(16)
            .fontColor('#666666')
          Blank()
          Text(this.temperature.toFixed(1) + ' °C')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isOverheat ? '#F44336' : '#333333')
        }
        .width('100%')
        .padding(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .margin({ bottom: 10 })

        // 速度显示
        Row() {
          Text('转速')
            .fontSize(16)
            .fontColor('#666666')
          Blank()
          Text(this.speed.toFixed(0) + ' RPM')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
        }
        .width('100%')
        .padding(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .margin({ bottom: 10 })

        // 运行时间显示
        Row() {
          Text('运行时间')
            .fontSize(16)
            .fontColor('#666666')
          Blank()
          Text(this.formatTime(this.runTimeSeconds))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
        }
        .width('100%')
        .padding(15)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .margin({ bottom: 10 })
      }
      .width('100%')
      .padding(15)

      // 告警显示
      if (this.lastAlert !== '') {
        Row() {
          Text('⚠ ' + this.lastAlert)
            .fontSize(14)
            .fontColor('#FFFFFF')
        }
        .width('90%')
        .padding(10)
        .backgroundColor('#FF5722')
        .borderRadius(8)
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 15 })
      }

      // 控制按钮区域
      Column() {
        Text('控制面板')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 15 })

        Row() {
          // 启动按钮
          Button('启动')
            .width('45%')
            .height(50)
            .fontSize(16)
            .backgroundColor('#4CAF50')
            .onClick(() => {
              this.sendCommand('start')
            })

          // 停止按钮
          Button('停止')
            .width('45%')
            .height(50)
            .fontSize(16)
            .backgroundColor('#F44336')
            .onClick(() => {
              this.sendCommand('stop')
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 10 })

        Row() {
          // 静音按钮
          Button('静音')
            .width('45%')
            .height(50)
            .fontSize(16)
            .backgroundColor('#FF9800')
            .onClick(() => {
              this.sendCommand('mute')
            })

          // 取消静音按钮
          Button('取消静音')
            .width('45%')
            .height(50)
            .fontSize(16)
            .backgroundColor('#2196F3')
            .onClick(() => {
              this.sendCommand('unmute')
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 10 })

        // 清除堵塞按钮
        Button('清除堵塞')
          .width('100%')
          .height(50)
          .fontSize(16)
          .backgroundColor('#9C27B0')
          .onClick(() => {
            this.sendCommand('clear_jam')
            // 堵塞状态将在收到MQTT状态更新后自动清除
          })
      }
      .width('100%')
      .padding(15)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
