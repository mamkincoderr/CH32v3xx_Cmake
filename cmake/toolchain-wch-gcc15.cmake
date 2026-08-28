set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR riscv32)

set(WCH_TOOLCHAIN_PREFIX "riscv32-wch-elf-")

# ---------------------------------------------------------------------------
# Путь к тулчейну НЕ зашит в проект. Он разрешается в таком порядке:
#   1. -DWCH_TOOLCHAIN_DIR=<...>/bin в командной строке cmake
#   2. переменная окружения WCH_TOOLCHAIN_DIR
#   3. riscv32-wch-elf-gcc, уже находящийся в PATH
#   4. типовые места установки MounRiver Studio 2 (диски C..F)
# Найденное значение кладётся в кэш, поэтому повторные конфигурации и
# try_compile ничего не переискивают.
# ---------------------------------------------------------------------------
if(NOT WCH_TOOLCHAIN_DIR AND DEFINED ENV{WCH_TOOLCHAIN_DIR})
    set(WCH_TOOLCHAIN_DIR "$ENV{WCH_TOOLCHAIN_DIR}")
endif()

if(NOT WCH_TOOLCHAIN_DIR)
    set(_wch_fallback_dirs "")
    foreach(_drive C D E F)
        foreach(_root
                "${_drive}:/MounRiver/MounRiver_Studio2"
                "${_drive}:/Program Files/MounRiver/MounRiver_Studio2"
                "${_drive}:/Program Files (x86)/MounRiver/MounRiver_Studio2")
            list(APPEND _wch_fallback_dirs
                 "${_root}/resources/app/resources/win32/components/WCH/Toolchain/RISC-V Embedded GCC15/bin")
        endforeach()
    endforeach()

    # PATHS (а не HINTS) — чтобы PATH имел приоритет над угадыванием установки.
    find_program(WCH_GCC_EXECUTABLE
        NAMES "${WCH_TOOLCHAIN_PREFIX}gcc"
        PATHS ${_wch_fallback_dirs}
        DOC "riscv32-wch-elf-gcc из MounRiver Studio 2")

    if(NOT WCH_GCC_EXECUTABLE)
        message(FATAL_ERROR
            "Не найден ${WCH_TOOLCHAIN_PREFIX}gcc.\n"
            "Укажите папку bin тулчейна одним из способов:\n"
            "  set WCH_TOOLCHAIN_DIR=<MounRiver_Studio2>/resources/app/resources/"
            "win32/components/WCH/Toolchain/RISC-V Embedded GCC15/bin\n"
            "  cmake -DWCH_TOOLCHAIN_DIR=<та же папка> ...\n"
            "  либо добавьте эту папку в PATH.")
    endif()

    get_filename_component(WCH_TOOLCHAIN_DIR "${WCH_GCC_EXECUTABLE}" DIRECTORY)
endif()

set(WCH_TOOLCHAIN_DIR "${WCH_TOOLCHAIN_DIR}" CACHE PATH
    "Папка bin тулчейна WCH RISC-V GCC")

# try_compile запускается как отдельный подпроект и не наследует кэш —
# пробрасываем найденный путь, иначе поиск повторится в каждом try_compile.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES WCH_TOOLCHAIN_DIR)

set(CMAKE_C_COMPILER   "${WCH_TOOLCHAIN_DIR}/${WCH_TOOLCHAIN_PREFIX}gcc.exe")
set(CMAKE_CXX_COMPILER "${WCH_TOOLCHAIN_DIR}/${WCH_TOOLCHAIN_PREFIX}g++.exe")
set(CMAKE_ASM_COMPILER "${WCH_TOOLCHAIN_DIR}/${WCH_TOOLCHAIN_PREFIX}gcc.exe")
set(CMAKE_OBJCOPY      "${WCH_TOOLCHAIN_DIR}/${WCH_TOOLCHAIN_PREFIX}objcopy.exe" CACHE FILEPATH "")
set(CMAKE_OBJDUMP      "${WCH_TOOLCHAIN_DIR}/${WCH_TOOLCHAIN_PREFIX}objdump.exe" CACHE FILEPATH "")
set(CMAKE_SIZE         "${WCH_TOOLCHAIN_DIR}/${WCH_TOOLCHAIN_PREFIX}size.exe" CACHE FILEPATH "")

# Bare-metal target: a full link during the compiler sanity-check would fail
# (no _start/nostartfiles), so restrict try_compile to just building a static lib.
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
