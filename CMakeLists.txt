# =============================================================================
# CH32v3xx_Cmake — Hello World template for CH32V203 / CH32V303 / CH32V307 (RISC-V)
# Author: mamkincoderr
#   https://github.com/mamkincoderr
#   https://t.me/oDeXteRo
#
# Build system copied from DCDC_Cmake (CMake + Ninja + GCC 15 from MRS2).
# Chip split follows official WCH EVT (openwch/ch32v307, openwch/ch32v20x):
#   CH32V203x  -> CH32V20x_D6  + startup_ch32v20x_D6.S   (soc/v20x, no FPU)
#   CH32V303x  -> CH32V30x_D8  + startup_ch32v30x_D8.S   (soc/v30x)
#   CH32V307x  -> CH32V30x_D8C + startup_ch32v30x_D8C.S  (soc/v30x)
#   Linker maps from EVT/EXAM/SRC/Ld/Link.ld (Table 32-3 in CH32FV2x_V3xRM)
#
# The v20x and v30x vendor SPL trees are kept fully separate under soc/<family>/
# (different core, headers, startup, linker map — never mixed). SOC_FAMILY below
# picks one.
#
# Chip is selected by hand in User/chip_select.h (CH32vxxx_CHIP), not by a
# CMake/build.bat argument — one MRS configuration, one obj/ output. CMake
# reads that file (and soc/v30x/System/ch32v307_mem.h for the 307 RAM split)
# with a regex, the same way it always reads a value that a human edits in source.
# =============================================================================

cmake_minimum_required(VERSION 3.20)

project(CH32v3xx_Cmake C ASM)

# ---------------------------------------------------------------------------
# CH32vxxx_CHIP — source of truth is User/chip_select.h.
# ---------------------------------------------------------------------------
file(READ "${CMAKE_SOURCE_DIR}/User/chip_select.h" _CHIP_SELECT_H)
if(NOT _CHIP_SELECT_H MATCHES "#define[ \t]+CH32vxxx_CHIP[ \t]+([0-9]+)")
    message(FATAL_ERROR "User/chip_select.h: could not find '#define CH32vxxx_CHIP <203|303|307>'")
endif()
set(CH32vxxx_CHIP_NUM "${CMAKE_MATCH_1}")

# CH32V307 RAM_CODE_MOD — source of truth is soc/v30x/System/ch32v307_mem.h.
# Read unconditionally (parse is cheap); only used by the 307 branch below.
file(READ "${CMAKE_SOURCE_DIR}/soc/v30x/System/ch32v307_mem.h" _MEM_H)
if(NOT _MEM_H MATCHES "\n#define[ \t]+CH32V307_MEM[ \t]+(MEM[0-9]+_[0-9]+)")
    message(FATAL_ERROR "soc/v30x/System/ch32v307_mem.h: could not find '#define CH32V307_MEM <mode>'")
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

# SOC_FAMILY selects the vendor SPL tree soc/<family>/ (v20x and v30x are
# separate trees — different core, headers, startup, linker map. Never mixed).
if(CH32vxxx_CHIP_NUM STREQUAL "307")
    set(SOC_FAMILY v30x)
    set(CHIP_DEFINE CH32V30x_D8C)
    set(STARTUP_FILE soc/v30x/Startup/startup_ch32v30x_D8C.S)
    configure_file(
        ${CMAKE_SOURCE_DIR}/soc/v30x/Ld/Link_ch32v307.ld.in
        ${CMAKE_BINARY_DIR}/Link_ch32v307.ld
        @ONLY
    )
    set(LINKER_SCRIPT ${CMAKE_BINARY_DIR}/Link_ch32v307.ld)
    set(CHIP_FLASH_NOTE "FLASH ${V307_FLASH_LEN} + RAM ${V307_RAM_LEN} + SLOWFLASH ${V307_SLOW_LEN} (${CH32V307_MEM})")
elseif(CH32vxxx_CHIP_NUM STREQUAL "303")
    set(SOC_FAMILY v30x)
    set(CHIP_DEFINE CH32V30x_D8)
    set(STARTUP_FILE soc/v30x/Startup/startup_ch32v30x_D8.S)
    set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/soc/v30x/Ld/Link_ch32v303.ld)
    set(CHIP_FLASH_NOTE "FLASH 128K R0WAIT + SLOWFLASH 352K + RAM 32K (CH32V303CB/RB)")
elseif(CH32vxxx_CHIP_NUM STREQUAL "203")
    set(SOC_FAMILY v20x)
    set(CHIP_DEFINE CH32V20x_D6)
    set(STARTUP_FILE soc/v20x/Startup/startup_ch32v20x_D6.S)
    set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/soc/v20x/Ld/Link_ch32v203.ld)
    set(CHIP_FLASH_NOTE "FLASH 64K R0WAIT + SLOWFLASH 160K + RAM 20K (CH32V203 D6, 224K user flash)")
else()
    message(FATAL_ERROR "User/chip_select.h: CH32vxxx_CHIP='${CH32vxxx_CHIP_NUM}', must be 203, 303 or 307.")
endif()

set(SOC_DIR "${CMAKE_SOURCE_DIR}/soc/${SOC_FAMILY}")

set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/User/chip_select.h"
    "${CMAKE_SOURCE_DIR}/soc/v30x/System/ch32v307_mem.h"
)

message(STATUS "========== CH32vxxx_CHIP=${CH32vxxx_CHIP_NUM}  ${CHIP_DEFINE} ==========")
message(STATUS "Target CH32V${CH32vxxx_CHIP_NUM} (${CHIP_DEFINE}), ${CHIP_FLASH_NOTE}")
message(STATUS "Startup ${STARTUP_FILE}")
message(STATUS "Linker  ${LINKER_SCRIPT}")
file(WRITE "${CMAKE_BINARY_DIR}/built_as.txt"
    "CHIP=CH32V${CH32vxxx_CHIP_NUM}\nDEFINE=${CHIP_DEFINE}\nSTARTUP=${STARTUP_FILE}\nLINKER=${LINKER_SCRIPT}\nNOTE=${CHIP_FLASH_NOTE}\n")

# ---------------------------------------------------------------------------
# CPU_FLAGS — arch/abi differ by family:
#   v30x (CH32V303/307): QingKe V4F, FPU  -> rv32imafcxw / ilp32f
#   v20x (CH32V203 D6):  QingKe V4B/C, no FPU -> rv32imacxw / ilp32
# The rest (medlow, small-data, strict-align, save-restore, tune=size) is the
# same set as DCDC_Cmake / official WCH GCC examples for both.
# ---------------------------------------------------------------------------
if(SOC_FAMILY STREQUAL "v20x")
    set(CPU_ARCH_FLAGS -march=rv32imacxw -mabi=ilp32)
else()
    set(CPU_ARCH_FLAGS -march=rv32imafcxw -mabi=ilp32f)
endif()

set(CPU_FLAGS
    ${CPU_ARCH_FLAGS}
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

# SoC/vendor code (soc/<family>/**) doesn't #include "chip_select.h" itself —
# force-include it so ch32v30x.h / ch32v20x.h picks the family macro
# (CH32V30x_D8 / D8C / CH32V20x_D6). main.c also #includes it directly (plain,
# include-guarded): that's what lets the MRS 1.92 editor/indexer resolve
# #if CH32vxxx_CHIP == ... correctly without any -D/-include awareness.
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
    ${SOC_DIR}/Debug
    ${SOC_DIR}/Core
    ${SOC_DIR}/System
    ${SOC_DIR}/Peripheral/inc
    ${CMAKE_SOURCE_DIR}/User
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

# SoC folders come from the selected soc/<family>/ tree. objs_soc_system also
# picks up the chip-specific bits that used to sit in User/ (v30x: SetMemory.c,
# ch32v30x_it.c; v20x: ch32v20x_it.c). User/ is now app-only (main.c).
add_folder_objects(objs_core        soc/${SOC_FAMILY}/Core           -O0)
add_folder_objects(objs_debug       soc/${SOC_FAMILY}/Debug          -O0)
add_folder_objects(objs_soc_system  soc/${SOC_FAMILY}/System         -O0)
add_folder_objects(objs_user        User                            -O0)
add_folder_objects(objs_peripheral  soc/${SOC_FAMILY}/Peripheral/src -Ofast)

# Startup is explicit (not GLOB): linking several startup_*.S would duplicate
# the vector table / Reset_Handler. Official EVT: pick one file per chip.
add_library(objs_startup OBJECT ${STARTUP_FILE})
target_compile_options(objs_startup PRIVATE
    ${CPU_FLAGS} -fmessage-length=0 -fsigned-char
    -ffunction-sections -fdata-sections -fno-common
    ${LTO_FLAGS} -Wunused -Wuninitialized -g -x assembler-with-cpp)
target_compile_definitions(objs_startup PRIVATE ${CHIP_DEFINE})
target_include_directories(objs_startup PRIVATE ${SOC_DIR}/Startup)
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
    LINK_DEPENDS "${LINKER_SCRIPT};${CMAKE_SOURCE_DIR}/soc/v30x/Ld/Link_ch32v307.ld.in"
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
