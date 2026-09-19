cmake_minimum_required(VERSION 3.21)

project(XdrMini
    VERSION 1.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Qt6 REQUIRED COMPONENTS
    Quick
    QuickControls2
    Network
    SerialPort
    Positioning
)

qt_standard_project_setup()

qt_add_executable(XdrMini
    src/main.cpp
    src/XdrClient.cpp
    src/XdrClient.h
    src/ScanController.cpp
    src/ScanController.h
    src/LocationBridge.cpp
    src/LocationBridge.h
    src/TmcTablesGenerated.h
)

target_include_directories(XdrMini PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Die Dateien liegen physisch unter qml/,
# sollen im QML-Modul XdrMini aber direkt erscheinen.
set_source_files_properties(
    qml/Main.qml
    PROPERTIES
        QT_RESOURCE_ALIAS Main.qml
)

set_source_files_properties(
    qml/HandyView.qml
    PROPERTIES
        QT_RESOURCE_ALIAS HandyView.qml
)

set_source_files_properties(
    qml/HandyTmcView.qml
    PROPERTIES
        QT_RESOURCE_ALIAS HandyTmcView.qml
)

set_source_files_properties(
    qml/TmcWindow.qml
    PROPERTIES
        QT_RESOURCE_ALIAS TmcWindow.qml
)

set_source_files_properties(
    qml/ScanWindow.qml
    PROPERTIES
        QT_RESOURCE_ALIAS ScanWindow.qml
)

qt_add_qml_module(XdrMini
    URI XdrMini
    VERSION 1.0

    QML_FILES
        qml/Main.qml
        qml/HandyView.qml
        qml/HandyTmcView.qml
        qml/TmcWindow.qml
        qml/ScanWindow.qml
)

target_link_libraries(XdrMini PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    Qt6::SerialPort
    Qt6::Positioning
)

set_target_properties(XdrMini PROPERTIES
    OUTPUT_NAME xdrmini
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

if(ANDROID)
    # AndroidManifest.xml, Java-Foreground-Service und Android-Ressourcen.
    set_property(TARGET XdrMini PROPERTY
        QT_ANDROID_PACKAGE_SOURCE_DIR
        "${CMAKE_CURRENT_SOURCE_DIR}/android"
    )
endif()

install(TARGETS XdrMini
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
)

# Die Linux-/Debian-Paketdateien werden auf Android nicht benötigt.
if(NOT ANDROID)
    install(FILES
        packaging/xdrmini.desktop
        DESTINATION share/applications
    )

    install(FILES
        icons/xdrmini.png
        DESTINATION share/icons/hicolor/512x512/apps
    )

    set(CPACK_GENERATOR "DEB")
    set(CPACK_PACKAGE_NAME "xdrmini")
    set(CPACK_PACKAGE_VERSION "0.1.0")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "TEF6686 FM Radio Control")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Fred")
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)

    include(CPack)
endif()

# XDRMINI_HANDY_TMC_GPS_V1
