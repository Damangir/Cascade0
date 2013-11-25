cmake_minimum_required(VERSION 2.6)
 
project(Cascade)

SET( CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS}" )

SET(CMAKE_BUILD_TYPE RelWithDebInfo)
IF(NOT DEFINED TARGET_PREFIX)
  SET(TARGET_PREFIX "cascade-")
ENDIF(NOT DEFINED TARGET_PREFIX)

FIND_PACKAGE(ITK REQUIRED)
include(${ITK_USE_FILE})
include_directories(${Cascade_SOURCE_DIR})

add_executable(range range-main.cxx)
target_link_libraries(range ${ITK_LIBRARIES})

add_executable(train train-main.cxx)
target_link_libraries(train ${ITK_LIBRARIES})

add_executable(likelihood likelihood-main.cxx)
target_link_libraries(likelihood ${ITK_LIBRARIES})

add_executable(report report-main.cxx)
target_link_libraries(report ${ITK_LIBRARIES})

add_executable(inspect inspectstate-main.cxx)
target_link_libraries(inspect ${ITK_LIBRARIES})

add_executable(transform transform-main.cxx)
target_link_libraries(transform ${ITK_LIBRARIES})

add_executable(property-filter property-filter-main.cxx)
target_link_libraries(property-filter ${ITK_LIBRARIES})

add_executable(statistics-filter statistics-filter-main.cxx)
target_link_libraries(statistics-filter ${ITK_LIBRARIES})

#add_executable(register register-main.cxx)
#target_link_libraries(register ${ITK_LIBRARIES})

message("Installation root is ${CMAKE_INSTALL_PREFIX}")
foreach(targ train likelihood range report inspect property-filter statistics-filter transform)
 message("Install rule: ${targ} as ${TARGET_PREFIX}${targ}")
 set_property(TARGET ${targ} PROPERTY INSTALL_RPATH_USE_LINK_PATH true)
 set_property(TARGET ${targ} PROPERTY OUTPUT_NAME "${TARGET_PREFIX}${targ}")
 install(TARGETS
   ${targ}
   RUNTIME DESTINATION bin
   LIBRARY DESTINATION lib
   ARCHIVE DESTINATION lib
 )
endforeach()

# Third party executable
ADD_EXECUTABLE(c3d_affine_tool 3rdparty/AffineTransformTools/AffineTransformTool.cxx)
TARGET_LINK_LIBRARIES(c3d_affine_tool ${ITK_LIBRARIES})
