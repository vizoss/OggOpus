cmake_minimum_required(VERSION 3.18.1)
project(ogg_opus)

set(OPUS_SRC_DIR ${CMAKE_CURRENT_LIST_DIR}/third_part/opus-1.5.2)
set(OGG_SRC_DIR ${CMAKE_CURRENT_LIST_DIR}/third_part/libogg-1.3.5)

add_subdirectory(${OGG_SRC_DIR} ${CMAKE_BINARY_DIR}/libogg)
add_subdirectory(${OPUS_SRC_DIR} ${CMAKE_BINARY_DIR}/opus)
file(GLOB OGG_OPUS_C_FILES "${CMAKE_CURRENT_LIST_DIR}/ogg-opus/*.c")

add_library(ogg_opus SHARED ${OGG_OPUS_C_FILES} ${CMAKE_CURRENT_LIST_DIR}/ogg_opus.c)
target_include_directories(ogg_opus PRIVATE ${OGG_SRC_DIR}/include ${OPUS_SRC_DIR}/include)
target_link_options(ogg_opus PRIVATE "-Wl,-z,max-page-size=16384")
target_link_libraries(ogg_opus opus ogg log)

