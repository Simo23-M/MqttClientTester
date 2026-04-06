cmake_minimum_required(VERSION 3.16)
project(MqttClientTester VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Network Qml Quick QuickControls2 Widgets Mqtt)

qt_standard_project_setup()

# --- Platform icon setup ---
set(PLATFORM_SOURCES "")

if(APPLE)
    set(APP_ICON_MACOS "${CMAKE_CURRENT_SOURCE_DIR}/AppIcon.icns")
    set_source_files_properties(${APP_ICON_MACOS} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    list(APPEND PLATFORM_SOURCES ${APP_ICON_MACOS})
endif()

if(WIN32)
    list(APPEND PLATFORM_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/app.rc")
endif()

qt_add_executable(mqtt_tls_client_qml
    main.cpp
    mqttclient.cpp mqttclient.h
    mqtttreemodel.cpp mqtttreemodel.h
    applicationcontroller.cpp applicationcontroller.h
    commandqueue.cpp commandqueue.h
    ${PLATFORM_SOURCES}
)

qt_add_resources(mqtt_tls_client_qml "qml"
    PREFIX "/"
    FILES
        qml/main.qml
        # Components
        qml/components/qmldir
        qml/components/StyledTextField.qml
        qml/components/StyledButton.qml
        qml/components/StyledGroupBox.qml
        qml/components/FilePickerRow.qml
        qml/components/MessageDelegate.qml
        qml/components/LogDelegate.qml
        qml/components/QosBadge.qml
        qml/components/EmptyStateView.qml
        qml/components/ToastNotification.qml
        # Tabs
        qml/tabs/qmldir
        qml/tabs/BrokerLogsTab.qml
        qml/tabs/TopicsMessagesTab.qml
        qml/tabs/TopicManagementTab.qml
        qml/tabs/CommandQueueTab.qml
        # Dialogs
        qml/dialogs/qmldir
        qml/dialogs/MessageDetailDialog.qml
        qml/dialogs/PresetDetailDialog.qml
        qml/dialogs/JsonViewDialog.qml
        qml/dialogs/TopicFilterHelpDialog.qml
        # Utils
        qml/utils/PayloadFormatter.js
        # App icon (embedded for Linux window icon)
        AppIcon.png
)

target_link_libraries(mqtt_tls_client_qml PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::NetworkPrivate
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::Mqtt
)

set_target_properties(mqtt_tls_client_qml PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_ICON_FILE AppIcon.icns
    MACOSX_BUNDLE_BUNDLE_NAME "MQTT Client Tester"
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
    WIN32_EXECUTABLE TRUE
)

# --- Linux install targets ---
if(UNIX AND NOT APPLE)
    include(GNUInstallDirs)
    install(TARGETS mqtt_tls_client_qml DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES mqtt-client-tester.desktop
            DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
    install(FILES AppIcon.png
            DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps
            RENAME mqtt-client-tester.png)
endif()
