# =============================================================================
# CH32v3xx_Cmake — Hello World template for CH32V303 / CH32V307 (RISC-V)
# Author: mamkincoderr
#   https://github.com/mamkincoderr
#   https://t.me/oDeXteRo
#
# Build system copied from DCDC_Cmake (CMake + Ninja + GCC 15 from MRS2).
# Chip split follows official WCH EVT (openwch/ch32v307):
#   CH32V303x  -> CH32V30x_D8  + startup_ch32v30x_D8.S
#   CH32V307x  -> CH32V30x_D8C + startup_ch32v30x_D8C.S
#   Linker maps from EVT/EXAM/SRC/Ld/Link.ld (Table 32-3 in CH32FV2x_V3xRM)
#
# Chip is selected by hand in User/chip_select.h (CH32v3xx_CHIP), not by a
# CMake/build.bat argument — one MRS configuration, one obj/ output. CMake
# reads that file (and User/ch32v307_mem.h for the 307 RAM split) with a
# regex, the same way it always reads a value that a human edits in source.
# =============================================================================

cmake_minimum_required(VERSION 3.20)

project(CH32v3xx_Cmake C ASM)

# ---------------------------------------------------------------------------
# CH32v3xx_CHIP — source of truth is User/chip_select.h.
# ---------------------------------------------------------------------------
file(READ "${CMAKE_SOURCE_DIR}/User/chip_select.h" _CHIP_SELECT_H)
if(NOT _CHIP_SELECT_H MATCHES "#define[ \t]+CH32v3xx_CHIP[ \t]+([0-9]+)")
    message(FATAL_ERROR "User/chip_select.h: could not find '#define CH32v3xx_CHIP <303|307>'")
endif()
set(CH32v3xx_CHIP_NUM "${CMAKE_MATCH_1}")

# CH32V307 RAM_CODE_MOD — source of truth is User/ch32v307_mem.h.
file(READ "${CMAKE_SOURCE_DIR}/User/ch32v307_mem.h" _MEM_H)
if(NOT _MEM_H MATCHES "\n#define[ \t]+CH32V307_MEM[ \t]+(MEM[0-9]+_[0-9]+)")
    message(FATAL_ERROR "User/ch32v307_mem.h: could not find '#define CH32V307_MEM <mode>'")
endif()
set(CH32V307_MEM "${CMAKE_MATCH_1}")

if(CH32V307_MEM STREQUAL "MEM288_32")
    set(V307_FLASH_LEN "288K")
    set(V307_SLOW_ORIGIN "0x00048000")
    set(V307_SLOW_LEN "192K")
    set(V307_RAM_LEN "32K")
elseif(CH32V307_MEM STREQUAL "MEM256_64")
    set(V307_FLASH_LEN "256K")
    set(V307_SLOW_ORIGIN "0x00040000")
    set(V307_SLOW_LEN "224K")
    set(V307_RAM_LEN "64K")
elseif(CH32V307_MEM STREQUAL "MEM224_96")
    set(V307_FLASH_LEN "224K")
    set(V307_SLOW_ORIGIN "0x00038000")
    set(V307_SLOW_LEN "256K")
    set(V307_RAM_LEN "96K")
elseif(CH32V307_MEM STREQUAL "MEM192_128")
    set(V307_FLASH_LEN "192K")
    set(V307_SLOW_ORIGIN "0x00030000")
    set(V307_SLOW_LEN "288K")
    set(V307_RAM_LEN "128K")
else()
    message(FATAL_ERROR "Unknown CH32V307_MEM='${CH32V307_MEM}'. Use MEM288_32, MEM256_64, MEM224_96 or MEM192_128 in User/ch32v307_mem.h")
endif()

if(CH32v3xx_CHIP_NUM STREQUAL "307")
    set(CHIP_DEFINE CH32V30x_D8C)
    set(STARTUP_FILE Startup/startup_ch32v30x_D8C.S)
    configure_file(
        ${CMAKE_SOURCE_DIR}/Ld/Link_ch32v307.ld.in
        ${CMAKE_BINARY_DIR}/Link_ch32v307.ld
        @ONLY
    )
    set(LINKER_SCRIPT ${CMAKE_BINARY_DIR}/Link_ch32v307.ld)
    set(CHIP_FLASH_NOTE "FLASH ${V307_FLASH_LEN} + RAM ${V307_RAM_LEN} + SLOWFLASH ${V307_SLOW_LEN} (${CH32V307_MEM})")
elseif(CH32v3xx_CHIP_NUM STREQUAL "303")
    set(CHIP_DEFINE CH32V30x_D8)
    set(STARTUP_FILE Startup/startup_ch32v30x_D8.S)
    set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/Ld/Link_ch32v303.ld)
    set(CHIP_FLASH_NOTE "FLASH 128K R0WAIT + SLOWFLASH 352K + RAM 32K (CH32V303CB/RB)")
else()
    message(FATAL_ERROR "User/chip_select.h: CH32v3xx_CHIP='${CH32v3xx_CHIP_NUM}', must be 303 or 307.")
endif()

set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/User/chip_select.h"
    "${CMAKE_SOURCE_DIR}/User/ch32v307_mem.h"
)

message(STATUS "========== CH32v3xx_CHIP=${CH32v3xx_CHIP_NUM}  ${CHIP_DEFINE} ==========")
message(STATUS "Target CH32V${CH32v3xx_CHIP_NUM} (${CHIP_DEFINE}), ${CHIP_FLASH_NOTE}")
message(STATUS "Startup ${STARTUP_FILE}")
message(STATUS "Linker  ${LINKER_SCRIPT}")
file(WRITE "${CMAKE_BINARY_DIR}/built_as.txt"
    "CHIP=CH32V${CH32v3xx_CHIP_NUM}\nDEFINE=${CHIP_DEFINE}\nSTARTUP=${STARTUP_FILE}\nLINKER=${LINKER_SCRIPT}\nNOTE=${CHIP_FLASH_NOTE}\n")

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

# Core/Debug/Peripheral don't #include "chip_select.h" themselves (SPL/vendor
# code) — force-include it so ch32v30x.h picks CH32V30x_D8 vs D8C. main.c
# also #includes it directly (plain, include-guarded): that's what lets the
# MRS 1.92 editor/indexer resolve #if CH32v3xx_CHIP == ... correctly without
# any -D/-include awareness, matching a normal #include search.
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
    -include ${CMAKE_SOURCE_DIR}/User/chip_select.h
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
target_compile_definitions(objs_startup PRIVATE ${CHIP_DEFINE})
target_include_directories(objs_startup PRIVATE ${CMAKE_SOURCE_DIR}/Startup)
set_property(GLOBAL APPEND PROPERTY ALL_FOLDER_OBJECT_LIBS objs_startup)

get_property(ALL_OBJECT_LIBS GLOBAL PROPERTY ALL_FOLDER_OBJECT_LIBS)
set(ALL_OBJECTS "")
foreach(lib ${ALL_OBJECT_LIBS})
    list(APPEND ALL_OBJECTS $<TARGET_OBJECTS:${lib}>)
endforeach()

add_executable(${PROJECT_NAME} ${ALL_OBJECTS})
target_compile_definitions(${PROJECT_NAME} PRIVATE ${CHIP_DEFINE})

# -O0 on the link line is required when -flto is on (same gotcha as DCDC_Cmake).
target_link_options(${PROJECT_NAME} PRIVATE
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
    -Wl,-Map,${PROJECT_NAME}.map
    --specs=nano.specs
    --specs=nosys.specs
)
set_target_properties(${PROJECT_NAME} PROPERTIES
    LINK_DEPENDS "${LINKER_SCRIPT};${CMAKE_SOURCE_DIR}/Ld/Link_ch32v307.ld.in"
    SUFFIX ".elf"
    OUTPUT_NAME ${PROJECT_NAME}
)

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.hex
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${PROJECT_NAME}> ${PROJECT_NAME}.bin
    COMMAND ${CMAKE_SIZE} --format=berkeley $<TARGET_FILE:${PROJECT_NAME}>
    BYPRODUCTS ${PROJECT_NAME}.hex ${PROJECT_NAME}.bin
    COMMENT "Generating ${PROJECT_NAME}.hex / ${PROJECT_NAME}.bin and size summary"
)
