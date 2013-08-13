cmake_minimum_required(VERSION 2.6)
 
project(Cascade)

SET(CMAKE_BUILD_TYPE RelWithDebInfo)
IF(NOT DEFINED TARGET_PREFIX)
  SET(TARGET_PREFIX "cascade-")
ENDIF(NOT DEFINED TARGET_PREFIX)

FIND_PACKAGE(ITK REQUIRED)
include(${ITK_USE_FILE})
include_directories(${Cascade_SOURCE_DIR})

add_executable(smoothing smoothing-main.cxx)
target_link_libraries(smoothing ${ITK_LIBRARIES})

add_executable(normalize normalizer-main.cxx)
target_link_libraries(normalize ${ITK_LIBRARIES})

add_executable(outlier outlier-main.cxx)
target_link_libraries(outlier ${ITK_LIBRARIES})

message("Installation root is ${CMAKE_INSTALL_PREFIX}")
foreach(targ smoothing normalize outlier)
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
