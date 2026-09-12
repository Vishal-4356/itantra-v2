cmake_minimum_required(VERSION 3.18.1)
project("itantra_native" C CXX)

set(JNI_LIBS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}")

add_library(onnxruntime SHARED IMPORTED)
set_target_properties(onnxruntime PROPERTIES IMPORTED_LOCATION
    ${JNI_LIBS_DIR}/libonnxruntime.so)

add_library(sherpa_onnx_c SHARED IMPORTED)
set_target_properties(sherpa_onnx_c PROPERTIES IMPORTED_LOCATION
    ${JNI_LIBS_DIR}/libsherpa-onnx-c-api.so)

add_library(itantra_native SHARED
    native_bridge.cpp
)

target_link_libraries(itantra_native
    onnxruntime
    sherpa_onnx_c
    log
)
