/*
 * Smart Conveyor Belt System - ArkTS UI
 *
 * This UI interfaces with the code9 Smart Conveyor Belt System
 * via HTTP polling (requires HTTP server on PC side).
 *
 * WiFi: zys / 12345678
 * Server IP: 192.168.43.230
 * HTTP Port: 8080
 */

import http from '@ohos.net.http';

// Server Configuration
const SERVER_HOST: string = '192.168.43.230';
const SERVER_PORT: number = 8080;
const POLL_INTERVAL: number = 2000; // Poll every 2 seconds

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

  // HTTP client and polling timer
  private httpRequest: http.HttpRequest | null = null;
  private pollingTimer: number | null = null;

  // Temperature threshold (same as code9: 30°C)
  private readonly TEMP_THRESHOLD: number = 30.0;

  aboutToAppear(): void {
    this.startPolling();
  }

  aboutToDisappear(): void {
    this.stopPolling();
  }

  // Start HTTP polling
  private startPolling(): void {
    this.connectionStatus = '连接中...';
    this.httpRequest = http.createHttp();
    this.fetchData();

    // Set up periodic polling
    this.pollingTimer = setInterval(() => {
      this.fetchData();
    }, POLL_INTERVAL);
  }

  // Fetch data from HTTP server
  private fetchData(): void {
    if (!this.httpRequest) {
      return;
    }

    const url = `http://${SERVER_HOST}:${SERVER_PORT}/conveyor`;

    this.httpRequest.request(url, {
      method: http.RequestMethod.GET,
      header: {
        'Content-Type': 'application/json'
      },
      connectTimeout: 5000,
      readTimeout: 5000
    }).then((response: http.HttpResponse) => {
      if (response.responseCode === 200) {
        this.isConnected = true;
        this.connectionStatus = '已连接';
        this.parseResponse(response.result as string);
      } else {
        this.isConnected = false;
        this.connectionStatus = '服务器错误';
      }
    }).catch((err: Error) => {
      console.error('[HTTP] Request failed: ' + err.message);
      this.isConnected = false;
      this.connectionStatus = '连接失败';
    });
  }

  // Parse server response
  private parseResponse(jsonStr: string): void {
    try {
      const data: ConveyorStatus = JSON.parse(jsonStr);

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

      console.info(`[HTTP] Data received - Item: ${this.hasItem}, Temp: ${this.temperature}, Motor: ${this.motorRunning}`);
    } catch (error) {
      console.error('[HTTP] Parse error: ' + error);
    }
  }

  // Stop HTTP polling
  private stopPolling(): void {
    if (this.pollingTimer !== null) {
      clearInterval(this.pollingTimer);
      this.pollingTimer = null;
    }
    if (this.httpRequest) {
      this.httpRequest.destroy();
      this.httpRequest = null;
    }
  }

  // Reconnect to server
  private reconnect(): void {
    this.stopPolling();
    this.connectionStatus = '重新连接中...';
    this.isConnected = false;
    setTimeout(() => {
      this.startPolling();
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

        Text(`服务器: ${SERVER_HOST}:${SERVER_PORT}`)
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