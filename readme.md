# MQTT TLS Client (QML Version)

A modern Qt 6 QML application for connecting to MQTT brokers with TLS certificate support, featuring a responsive Material Design interface.

note:
Tested only in ubuntu 24, should work also with other platform.

## Features

- **QML Interface**: Material Design with dark theme support
- **Secure TLS Connection**: Support for CA certificates and client certificates
- **Real-time Messaging**: Subscribe to topics and publish messages with live updates
- **Responsive UI**: Adaptive layout that works on different screen sizes
- **Activity Logging**: Real-time log with auto-scroll and clear functionality
- **File Browser Integration**: Native file dialogs for certificate selection
- **Connection Management**: Visual connection status with color-coded indicators


## Project Structure

```
mqtt_tls_client_qml/
├── mqtt_tls_client_qml.pro    # QMake project file
├── main.cpp                   # Application entry point
├── mqttclient.h/.cpp         # MQTT client with QML integration
├── applicationcontroller.h/.cpp # File dialogs and utilities
├── main.qml                   # Main QML interface
├── qml.qrc                    # QML resources
└── README.md                  # This file
```

## Requirements

- Qt 6.0 or later with the following modules:
  - Qt Core
  - Qt Quick
  - Qt Quick Controls 2
  - Qt MQTT
  - Qt Network
- OpenSSL libraries (for TLS support)
- Qt Material Style (included with Qt Quick Controls 2)

## Build Instructions

### Prerequisites

1. **Install Qt 6** with QML support:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install qt6-base-dev qt6-declarative-dev qt6-mqtt-dev
   ```

2. **Install OpenSSL**:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install libssl-dev
   ```

### Compilation

1. **Clone or download** the source code
2. **Navigate** to the project directory
3. **Build** the project:

```bash
# Using qmake
qmake mqtt_tls_client_qml.pro
make

# Using Qt Creator
# 1. Open mqtt_tls_client_qml.pro in Qt Creator
# 2. Configure the project for your Qt 6 kit
# 3. Build and run
```

### Running the Application

```bash
./mqtt_tls_client_qml
```

## User Interface Guide

### Connection Panel
- **Host**: MQTT broker hostname or IP address
- **Port**: Broker port (default: 8883 for TLS)
- **Client ID**: Unique identifier (auto-generated if empty)
- **Username/Password**: Optional authentication credentials
- **Connection Status**: Visual indicator (Green=Connected, Orange=Connecting, Red=Disconnected)

### TLS Configuration
- **CA Certificate**: Certificate Authority file for server verification
- **Client Certificate**: Your client certificate for mutual TLS authentication
- **Client Key**: Private key corresponding to the client certificate
- **Browse Buttons**: Native file dialogs for easy certificate selection

### Messaging
- **Subscribe Section**: Enter topic patterns and manage subscriptions
- **Publish Section**: Send messages to specific topics
- **Activity Log**: Real-time display of all MQTT activities with timestamps

## QML Features

### Material Design
The application uses Qt's Material Design style with:
- Dark theme by default
- Blue primary color scheme

### Responsive Layout
- **Two-panel layout**: Controls on left, log on right 
- **Scrollable panels**: Adapts to different screen sizes
- **Flexible sizing**: Panels resize based on content and window size

### Real-time Updates
- **Property binding**: UI automatically updates when connection state changes
- **Live logging**: Messages appear instantly in the activity log
- **Status indicators**: Connection status updates in real-time

## Configuration Examples

### Eclipse Mosquitto (Public Test Server)
```
Host: test.mosquitto.org
Port: 8883
CA Certificate: mosquitto.org.crt
```

### Local Mosquitto with TLS
```
Host: localhost
Port: 8883
CA Certificate: ca.crt
Client Certificate: client.crt
Client Key: client.key
```

## QML Architecture

### C++ Backend
- **MqttClient**: Handles MQTT protocol and TLS configuration
- **Property Binding**: Seamless data flow between C++ and QML

### QML Frontend
- **Declarative UI**: Clean, maintainable interface code
- **Material Components**: Professional-looking controls
- **Data Binding**: Automatic UI updates without manual synchronization

## Development Notes

### Adding New Features
- **QML Components**: Add new UI elements in main.qml 
- **C++ Integration**: Extend MqttClient or ApplicationController classes
- **Property Binding**: Use Q_PROPERTY for automatic UI updates

### TODO
- **Mqtt Topic preset**: Add a section for selection a preconfiguration of mqtt topics
- **Graphic** make 2 tabs the first for setting and logs, the second for topics management


### Customization
- **Themes**: Modify Material.theme and color properties

## License
This project is provided as-is for educational and development purposes.
