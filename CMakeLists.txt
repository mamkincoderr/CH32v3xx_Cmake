# =============================================================================
# CH32v3xx_Cmake — Hello World template for CH32V303 / CH32V307 (RISC-V)
# Author: mamkincoderr
#   https://github.com/mamkincoderr
#   https://t.me/mamkincoderr
#
# Build system copied from DCDC_Cmake (CMake + Ninja + GCC 15 from MRS2).
# Chip split follows official WCH EVT (openwch/ch32v307):
#   CH32V303x  -> CH32V30x_D8  + startup_ch32v30x_D8.S
#   CH32V307x  -> CH32V30x_D8C + startup_ch32v30x_D8C.S
#   Linker maps from EVT/EXAM/SRC/Ld/Link.ld (Table 32-3 in CH32FV2x_V3xRM)
#
#   cmake -DCHIP=CH32V303 ...     (default, this board)
#   cmake -DCHIP=CH32V307 ...
# =============================================================================

cmake_minimum_required(VERSION 3.20)

project(CH32v3xx_Cmake C ASM)

set(CHIP "CH32V303" CACHE STRING "Target MCU: CH32V303 or CH32V307")
set_property(CACHE CHIP PROPERTY STRINGS CH32V303 CH32V307)

if(CHIP STREQUAL "CH32V307")
    set(CHIP_DEFINE CH32V30x_D8C)
    set(STARTUP_FILE Startup/startup_ch32v30x_D8C.S)
    set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/Ld/Link_ch32v307.ld)
    set(CHIP_FLASH_NOTE "FLASH 288K + RAM 32K (EVT default)")
elseif(CHIP STREQUAL "CH32V303")
    set(CHIP_DEFINE CH32V30x_D8)
    set(STARTUP_FILE Startup/startup_ch32v30x_D8.S)
    set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/Ld/Link_ch32v303.ld)
    set(CHIP_FLASH_NOTE "FLASH 128K + RAM 32K (CH32V303CB/RB)")
else()
    message(FATAL_ERROR "Unknown CHIP='${CHIP}'. Use CH32V303 or CH32V307.")
endif()

message(STATUS "Target ${CHIP} (${CHIP_DEFINE}), ${CHIP_FLASH_NOTE}")
message(STATUS "Startup ${STARTUP_FILE}")
message(STATUS "Linker  ${LINKER_SCRIPT}")

# ---------------------------------------------------------------------------
# CPU_FLAGS — same RISC-V4F set as DCDC_Cmake / official WCH GCC examples.
# ---------------------------------------------------------------------------
set(CPU_FLAGS
    -march=rv32imafcxw
    -mabi=ilp32f
    -mtune=size
    -mcmodel=medlow
    -msmall-data-limit=8
    -mstrict-align
    -msave-restore
)

option(ENABLE_LTO "Interprocedural -flto (hurts source-level debug)" OFF)
if(ENABLE_LTO)
    set(LTO_FLAGS -flto)
else()
    set(LTO_FLAGS "")
endif()

set(COMMON_C_FLAGS
    ${CPU_FLAGS}
    -fmessage-length=0
    -fsigned-char
    -ffunction-sections
    -fdata-sections
    -fno-common
    ${LTO_FLAGS}
    -Wunused
    -Wuninitialized
    -g
    -std=gnu99
)

set(COMMON_INCLUDES
    ${CMAKE_SOURCE_DIR}/Debug
    ${CMAKE_SOURCE_DIR}/Core
    ${CMAKE_SOURCE_DIR}/User
    ${CMAKE_SOURCE_DIR}/Peripheral/inc
)

function(add_folder_objects TARGET FOLDER OPT_LEVEL)
    file(GLOB ${TARGET}_SRCS CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/${FOLDER}/*.c")
    if(NOT ${TARGET}_SRCS)
        message(FATAL_ERROR "add_folder_objects(${TARGET}): no .c files found in ${FOLDER}")
    endif()
    add_library(${TARGET} OBJECT ${${TARGET}_SRCS})
    target_compile_options(${TARGET} PRIVATE ${COMMON_C_FLAGS} ${OPT_LEVEL})
    target_compile_definitions(${TARGET} PRIVATE ${CHIP_DEFINE})
    target_include_directories(${TARGET} PRIVATE ${COMMON_INCLUDES})
    set_property(GLOBAL APPEND PROPERTY ALL_FOLDER_OBJECT_LIBS ${TARGET})
endfunction()

add_folder_objects(objs_core        Core            -O0)
add_folder_objects(objs_debug       Debug           -O0)
add_folder_objects(objs_user        User            -O0)
add_folder_objects(objs_peripheral  Peripheral/src  -Ofast)

# Startup is explicit (not GLOB): linking both D8 and D8C would duplicate
# the vector table / Reset_Handler. Official EVT: pick one file, exclude the other.
add_library(objs_startup OBJECT ${STARTUP_FILE})
target_compile_options(objs_startup PRIVATE
    ${CPU_FLAGS} -fmessage-length=0 -fsigned-char
    -ffunction-sections -fdata-sections -fno-common
    ${LTO_FLAGS} -Wunused -Wuninitialized -g -x assembler-with-cpp)
target_include_directories(objs_startup PRIVATE ${CMAKE_SOURCE_DIR}/Startup)
set_property(GLOBAL APPEND PROPERTY ALL_FOLDER_OBJECT_LIBS objs_startup)

get_property(ALL_OBJECT_LIBS GLOBAL PROPERTY ALL_FOLDER_OBJECT_LIBS)
set(ALL_OBJECTS "")
foreach(lib ${ALL_OBJECT_LIBS})
    list(APPEND ALL_OBJECTS $<TARGET_OBJECTS:${lib}>)
endforeach()

add_executable(${CHIP} ${ALL_OBJECTS})
target_compile_definitions(${CHIP} PRIVATE ${CHIP_DEFINE})

# -O0 on the link line is required when -flto is on (same gotcha as DCDC_Cmake).
target_link_options(${CHIP} PRIVATE
    ${CPU_FLAGS}
    -O0
    -fmessage-length=0
    -fsigned-char
    -ffunction-sections
    -fdata-sections
    -fno-common
    ${LTO_FLAGS}
    -Wunused
    -Wuninitialized
    -g
    -T${LINKER_SCRIPT}
    -nostartfiles
    -Wl,--gc-sections,--print-memory-usage
    -Wl,-Map,${CHIP}.map
    --specs=nano.specs
    --specs=nosys.specs
)
set_target_properties(${CHIP} PROPERTIES
    LINK_DEPENDS ${LINKER_SCRIPT}
    SUFFIX ".elf"
    OUTPUT_NAME ${CHIP}
)

add_custom_command(TARGET ${CHIP} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex $<TARGET_FILE:${CHIP}> ${CHIP}.hex
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${CHIP}> ${CHIP}.bin
    COMMAND ${CMAKE_SIZE} --format=berkeley $<TARGET_FILE:${CHIP}>
    BYPRODUCTS ${CHIP}.hex ${CHIP}.bin
    COMMENT "Generating ${CHIP}.hex / ${CHIP}.bin and size summary"
)
