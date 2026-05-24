cmake_minimum_required(VERSION 3.16)
project(MicYou)

set(MICYOU_SOURCES
    main.m
    AppDelegate.m
    SceneDelegate.m
    ViewControllers/MainViewController.m
    ViewControllers/SettingsViewController.m
    ViewControllers/MicYouViewController.m
    Audio/MicYouAudioCapture.m
    Audio/AudioBufferQueue.m
    Network/TransportClient.m
    Network/Protocol.m
    Utils/MicYouLogger.m
    Animation/MicYouAnimator.m
    Animation/MicYouEasing.m
    Theme/MicYouColors.m
)

set(MICYOU_HEADERS
    AppDelegate.h
    SceneDelegate.h
    ViewControllers/MainViewController.h
    ViewControllers/SettingsViewController.h
    ViewControllers/MicYouViewController.h
    Audio/MicYouAudioCapture.h
    Audio/AudioBufferQueue.h
    Network/TransportClient.h
    Network/Protocol.h
    Utils/MicYouLogger.h
    Animation/MicYouAnimator.h
    Animation/MicYouEasing.h
    Theme/MicYouColors.h
)

set(MICYOU_ASSETS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Assets.xcassets")
set(MICYOU_ICON "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Assets.xcassets/AppIcon.appiconset/app_icon.png")

add_executable(MicYou MACOSX_BUNDLE
    ${MICYOU_SOURCES}
    ${MICYOU_HEADERS}
    ${MICYOU_ICON}
)

set_source_files_properties(${MICYOU_ICON} PROPERTIES
    MACOSX_PACKAGE_LOCATION "Resources/Assets.xcassets/AppIcon.appiconset"
)

target_link_libraries(MicYou PRIVATE
    "-framework UIKit"
    "-framework Foundation"
    "-framework AVFoundation"
    "-framework AudioToolbox"
    "-framework CoreAudio"
    "-framework CFNetwork"
)

set_target_properties(MicYou PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist
    MACOSX_BUNDLE_BUNDLE_NAME "MicYou"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.lanrhyme.micyou.ios"
    MACOSX_BUNDLE_MINIMUM_IOS_VERSION "11.0"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
)

target_compile_options(MicYou PRIVATE
    -fobjc-arc
    -fmodules
)

target_include_directories(MicYou PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/ViewControllers
    ${CMAKE_CURRENT_SOURCE_DIR}/Audio
    ${CMAKE_CURRENT_SOURCE_DIR}/Network
    ${CMAKE_CURRENT_SOURCE_DIR}/Utils
    ${CMAKE_CURRENT_SOURCE_DIR}/Animation
    ${CMAKE_CURRENT_SOURCE_DIR}/Theme
)

set_property(TARGET MicYou PROPERTY
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.lanrhyme.micyou.ios"
)
