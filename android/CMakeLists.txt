cmake_minimum_required(VERSION 3.13)

# Project declaration
project(react-native-pinned-ws)

set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_CXX_STANDARD 17)

# Define library name
set(PACKAGE_NAME "react-native-pinned-ws")

# Convert input paths to CMake format
file(TO_CMAKE_PATH "${PROJECT_BUILD_DIR}" PROJECT_BUILD_DIR)
file(TO_CMAKE_PATH "${REACT_ANDROID_DIR}" REACT_ANDROID_DIR)
file(TO_CMAKE_PATH "${REACT_ANDROID_BUILD_DIR}" REACT_ANDROID_BUILD_DIR)
file(TO_CMAKE_PATH "${NODE_MODULES_DIR}" NODE_MODULES_DIR)

# For New Architecture (Fabric/TurboModules) - ensure codegen can link
if(EXISTS "${PROJECT_BUILD_DIR}/generated/source/codegen/jni")
  # Add the codegen directory - this contains the generated C++ code
  add_subdirectory("${PROJECT_BUILD_DIR}/generated/source/codegen/jni" ./codegen_build)
  
  # The actual implementation is in Java through JNI
  # The codegen library provides the TurboModule interface
endif()
