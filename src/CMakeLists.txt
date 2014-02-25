cmake_minimum_required(VERSION 2.6)
 
project(Cascade-Academic)

SET( CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS}" )

SET(CMAKE_BUILD_TYPE RelWithDebInfo)
IF(NOT DEFINED TARGET_PREFIX)
  SET(TARGET_PREFIX "cascade-")
ENDIF(NOT DEFINED TARGET_PREFIX)

FIND_PACKAGE(ITK REQUIRED)
include(${ITK_USE_FILE})
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

add_executable(range range-main.cxx)
target_link_libraries(range ${ITK_LIBRARIES})

add_executable(transform transform-main.cxx)
target_link_libraries(transform ${ITK_LIBRARIES})

add_executable(property-filter property-filter-main.cxx)
target_link_libraries(property-filter ${ITK_LIBRARIES})

add_executable(statistics-filter statistics-filter-main.cxx)
target_link_libraries(statistics-filter ${ITK_LIBRARIES})

message("Installation root is ${CMAKE_INSTALL_PREFIX}")
foreach(targ range property-filter statistics-filter transform )
  message("Install executable: ${TARGET_PREFIX}${targ}")
  set_property(TARGET ${targ} PROPERTY INSTALL_RPATH_USE_LINK_PATH true)
  set_property(TARGET ${targ} PROPERTY OUTPUT_NAME "${TARGET_PREFIX}${targ}")
  install(TARGETS
   ${targ}
   RUNTIME DESTINATION ${CMAKE_PROJECT_NAME}/bin
   LIBRARY DESTINATION ${CMAKE_PROJECT_NAME}/lib
   ARCHIVE DESTINATION ${CMAKE_PROJECT_NAME}/lib
  )
endforeach()

FILE(GLOB script_files "${CMAKE_SOURCE_DIR}/scripts/*.sh")
foreach(script ${script_files} )
  GET_FILENAME_COMPONENT(scriptName ${script} NAME )
  message("Install script: ${scriptName}")
  INSTALL(FILES ${script} DESTINATION ${CMAKE_PROJECT_NAME}/bin)
endforeach()

INSTALL( DIRECTORY ${CMAKE_SOURCE_DIR}/../data/atlas DESTINATION ${CMAKE_PROJECT_NAME}/data)
INSTALL( DIRECTORY ${CMAKE_SOURCE_DIR}/../data/histograms DESTINATION ${CMAKE_PROJECT_NAME}/data)
INSTALL( DIRECTORY ${CMAKE_SOURCE_DIR}/../data/mask DESTINATION ${CMAKE_PROJECT_NAME}/data)
INSTALL( DIRECTORY ${CMAKE_SOURCE_DIR}/../data/standard DESTINATION ${CMAKE_PROJECT_NAME}/data)
