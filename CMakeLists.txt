cmake_minimum_required(VERSION 3.16)
project(FrameExtractor VERSION 1.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_MACOSX_BUNDLE ON)
set(CMAKE_CXX_STANDARD 17)

if(WIN32)
set(CMAKE_WIN32_EXECUTABLE ON)
endif()

# Find Qt (prefer Qt6, fallback to Qt5 if needed)
find_package(Qt6 REQUIRED COMPONENTS Widgets)
find_package(Qt6 REQUIRED COMPONENTS Network)

# Set up Qt environment
qt_standard_project_setup()

# Add main executable
add_executable(FrameExtractor
src/FrameExtractor.cpp
src/utils/FindFFmpeg.cpp
src/utils/DownloadFFmpeg.cpp
src/utils/DownloadDialog.cpp
src/utils/GetVideoDuration.cpp
)

# Apply subsystem GUI (Windows only)
if(WIN32)
set_target_properties(FrameExtractor PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

# Link Qt libraries
target_link_libraries(FrameExtractor
Qt6::Widgets
Qt6::Network
)

if (WIN32)
target_link_libraries(FrameExtractor dwmapi)
endif()

# install target to AppDir structure
install(TARGETS FrameExtractor DESTINATION usr/bin)
install(FILES packaging/FrameExtractor.desktop DESTINATION .)
install(FILES packaging/AppRun DESTINATION . PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ)
