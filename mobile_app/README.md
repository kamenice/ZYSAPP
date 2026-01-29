# 传送带智能监控系统 - 手机端应用

这是一个基于Web的手机界面应用，用于监控和控制传送带智能系统。该界面以中文显示与OLED屏幕相同的信息。

## 功能特性

### 实时数据显示（与OLED显示内容对应）

| OLED显示 | 手机界面中文显示 | 说明 |
|---------|-----------------|------|
| `Wt:%.1fg OVR` | 重量: xxx克 [超重] | 当前物品重量及超重状态 |
| `St:RUN/STP JAM!` | 状态: 运行中/停止 [卡住!] | 传送带运行状态及卡住状态 |
| `Tp:%.1fC HOT` | 温度: xxx℃ [过热] | 当前环境温度及过热状态 |
| `Sp:%.0f T:MM:SS` | 速度: xxx RPM 时间: MM:SS | 传送带速度和运行时间 |

### 状态指示卡片

- **⚙️ 运行状态**: 显示传送带是否正在运行
- **🔧 卡住状态**: 显示是否检测到物品卡住
- **⚖️ 重量状态**: 显示是否超重
- **🌡️ 温度状态**: 显示是否过热

### 控制按钮

- **▶️ 启动**: 启动传送带 (`start` 命令)
- **⏹️ 停止**: 停止传送带 (`stop` 命令)
- **🔇 静音**: 静音蜂鸣器告警 (`mute` 命令)
- **🔧 清除卡住**: 触发振动清除卡住 (`clear_jam` 命令)

### 阈值设置

- **重量阈值**: 设置超重告警阈值（默认5000克）
- **温度阈值**: 设置过热告警阈值（默认60℃）

### OLED模拟显示

界面底部有一个模拟OLED显示屏的区域，以类似OLED的样式显示中文信息。

## 技术架构

### MQTT通信

应用通过MQTT协议与Hi3861设备进行通信：

- **服务器地址**: `192.168.43.230`
- **WebSocket端口**: `9001` (需要MQTT broker支持WebSocket)
- **TCP端口**: `1883` (设备端使用)

### MQTT主题

| 主题 | 说明 | 数据格式 |
|-----|------|---------|
| `conveyor/status` | 设备状态更新 | `{"weight":%.1f,"temp":%.1f,"speed":%.1f,"running":%d,"time":%u}` |
| `conveyor/control` | 控制命令 | `start`, `stop`, `mute`, `unmute`, `clear_jam`, `set_weight:值`, `set_temp:值` |
| `conveyor/alert` | 告警通知 | `{"alert":"类型","value":%.1f}` |

## 使用方法

### 方法一：直接打开HTML文件

1. 在手机浏览器中打开 `index.html` 文件
2. 确保手机连接到与设备相同的WiFi网络
3. 界面会自动尝试连接MQTT服务器

### 方法二：部署到Web服务器

1. 将 `index.html` 部署到Web服务器（如Nginx、Apache）
2. 使用HTTPS时需要配置MQTT broker支持WSS
3. 通过手机浏览器访问部署的URL

### 方法三：演示模式

如果无法连接到MQTT服务器，应用会在5秒后自动进入演示模式，显示模拟数据。

## 配置修改

如需修改MQTT服务器配置，请编辑 `index.html` 文件中的 `MQTT_CONFIG` 对象：

```javascript
const MQTT_CONFIG = {
    host: '192.168.43.230',  // MQTT服务器地址
    port: 9001,               // WebSocket端口
    clientId: 'mobile_app_xxx',
    username: 'conveyor',
    password: 'conveyor123',
    topics: {
        status: 'conveyor/status',
        control: 'conveyor/control',
        alert: 'conveyor/alert'
    }
};
```

## MQTT Broker配置

为了使手机端能够通过WebSocket连接到MQTT broker，需要在broker上启用WebSocket支持。

### Mosquitto配置示例

在 `/etc/mosquitto/mosquitto.conf` 中添加：

```
# 标准MQTT端口（设备使用）
listener 1883

# WebSocket端口（手机端使用）
listener 9001
protocol websockets
```

重启mosquitto服务后即可使用。

## 与设备代码的对应关系

### 显示函数对应

| C函数 | 手机界面显示 |
|-------|-------------|
| `OLED_DisplayWeight()` | 重量显示行 |
| `OLED_DisplayConveyorStatus()` | 状态指示卡片 |
| `OLED_DisplayTemperature()` | 温度显示行 |
| `OLED_DisplaySpeedAndTime()` | 速度和时间显示行 |

### 控制命令对应

| C定义 | 手机端发送 |
|-------|-----------|
| `CMD_START "start"` | `start` |
| `CMD_STOP "stop"` | `stop` |
| `CMD_MUTE "mute"` | `mute` |
| `CMD_UNMUTE "unmute"` | `unmute` |
| `CMD_CLEAR_JAM "clear_jam"` | `clear_jam` |
| `CMD_SET_WEIGHT_THRESHOLD "set_weight"` | `set_weight:值` |
| `CMD_SET_TEMP_THRESHOLD "set_temp"` | `set_temp:值` |

## 截图

界面设计为深色主题，适合工业监控场景，包含：

1. 连接状态指示
2. 告警面板（红色高亮）
3. 4个状态卡片（运行、卡住、超重、过热）
4. 实时数据面板（重量、温度、速度、时间）
5. OLED模拟显示（绿色字体黑色背景）
6. 控制按钮（启动、停止、静音、清除卡住）
7. 阈值设置区域

## 浏览器兼容性

- Chrome (推荐)
- Safari
- Firefox
- Edge

支持iOS和Android设备的移动端浏览器。
