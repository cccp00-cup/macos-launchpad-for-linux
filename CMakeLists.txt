cmake_minimum_required(VERSION 3.22)
project(Launchpad VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Qml Quick Gui Concurrent)
find_package(KF6GlobalAccel REQUIRED)

# 使用 :/qt/qml/ 标准资源前缀（loadFromModule 需要）
qt_policy(SET QTP0001 NEW)

qt_add_executable(launchpad
    src/main.cpp
)

qt_add_qml_module(launchpad
    URI Launchpad
    VERSION 1.0
    QML_FILES qml/Main.qml
)

target_link_libraries(launchpad PRIVATE
    Qt6::Qml
    Qt6::Quick
    Qt6::Gui
    Qt6::Concurrent
    KF6::GlobalAccel
)

# 安装到可执行文件目录，便于 ~/.local/bin 使用
install(TARGETS launchpad BUNDLE DESTINATION . LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
