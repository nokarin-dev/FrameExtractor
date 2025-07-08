find_package(Qt6 REQUIRED COMPONENTS Widgets Test)

add_executable(UnitTests
    test.cpp
    TestMainWindow.cpp
)

target_link_libraries(UnitTests
    Qt6::Widgets
    Qt6::Test
)

add_test(NAME unit_tests COMMAND UnitTests)