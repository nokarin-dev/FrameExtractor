cmake_minimum_required(VERSION 3.16)
project(FrameExtractor VERSION 1.0 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_CXX_STANDARD 17)

# Find Qt (prefer Qt6, fallback to Qt5 if needed)
find_package(Qt6 REQUIRED COMPONENTS Widgets)

# Set up Qt environment
qt_standard_project_setup()

# Add main executable
add_executable(FrameExtractor
src/FrameExtractor.cpp
src/utils/find_ffmpeg.cpp
)

# Link Qt libraries
target_link_libraries(FrameExtractor
Qt6::Widgets
)

# Optional: install target to AppDir structure
install(TARGETS FrameExtractor DESTINATION usr/bin)
install(FILES packaging/FrameExtractor.desktop DESTINATION .)
install(FILES packaging/AppRun DESTINATION . PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ GROUP_EXECUTE GROUP_READ WORLD_EXECUTE WORLD_READ)
