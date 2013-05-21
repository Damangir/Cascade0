cmake_minimum_required(VERSION 2.6)
 
project(Cascade)

SET(CMAKE_BUILD_TYPE RelWithDebInfo)
IF(NOT DEFINED TARGET_PREFIX)
  SET(TARGET_PREFIX "")
ENDIF(NOT DEFINED TARGET_PREFIX)

FIND_PACKAGE(ITK REQUIRED)
include(${ITK_USE_FILE})

SET(UTIL_SOURCE_FILES util.cpp)

add_executable(cascade cascade-main.cxx ${UTIL_SOURCE_FILES})
target_link_libraries(cascade ${ITK_LIBRARIES})

message("Installation root is ${CMAKE_INSTALL_PREFIX}")
foreach(targ cascade)
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
