/********************************** (C) COPYRIGHT *******************************
 * File Name          : chip_select.h
 * Author             : mamkincoderr
 *                      https://github.com/mamkincoderr
 *                      https://t.me/oDeXteRo
 * Description        : Hand-edit CH32vxxx_CHIP below to pick the target chip.
 *                      This is the ONLY place the chip is selected - build.bat
 *                      takes no chip argument, there is one MRS configuration,
 *                      one obj/ output.
 *
 *                      Plain header, normal #include (no CMake -D, no forced
 *                      -include): MRS 1.92's editor/indexer resolves it the
 *                      same way the real compiler does, so #if/#elif greying
 *                      in main.c matches what actually gets built.
 *
 *                      CMake reads this file (regex on the #define below) to
 *                      pick the startup file, linker script and flash/RAM map.
 *******************************************************************************/
#ifndef CH32vxxx_CHIP_SELECT_H
#define CH32vxxx_CHIP_SELECT_H

/* Pick one: 203, 303 or 307. */
#define CH32vxxx_CHIP   307

#if CH32vxxx_CHIP == 307
#define CH32vxxx_CHIP_STR "CH32V307"
#ifndef CH32V30x_D8C
#define CH32V30x_D8C
#endif
#elif CH32vxxx_CHIP == 303
#define CH32vxxx_CHIP_STR "CH32V303"
#ifndef CH32V30x_D8
#define CH32V30x_D8
#endif
#elif CH32vxxx_CHIP == 203
#define CH32vxxx_CHIP_STR "CH32V203"
/* CH32V203 F6/F8/G6/G8/K6/K8/C6/C8 — ch32v20x.h keys its family off this. */
#ifndef CH32V20x_D6
#define CH32V20x_D6
#endif
#else
#error "chip_select.h: CH32vxxx_CHIP must be 203, 303 or 307"
#endif

#endif
