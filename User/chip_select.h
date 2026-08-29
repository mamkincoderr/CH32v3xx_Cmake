/********************************** (C) COPYRIGHT *******************************
 * File Name          : chip_select.h
 * Author             : mamkincoderr
 *                      https://github.com/mamkincoderr
 *                      https://t.me/oDeXteRo
 * Description        : Hand-edit CH32v3xx_CHIP below to pick the target chip.
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
#ifndef CH32v3xx_CHIP_SELECT_H
#define CH32v3xx_CHIP_SELECT_H

/* Pick one: 303 or 307. */
#define CH32v3xx_CHIP   303

#if CH32v3xx_CHIP == 307
#define CH32v3xx_CHIP_STR "CH32V307"
#ifndef CH32V30x_D8C
#define CH32V30x_D8C
#endif
#elif CH32v3xx_CHIP == 303
#define CH32v3xx_CHIP_STR "CH32V303"
#ifndef CH32V30x_D8
#define CH32V30x_D8
#endif
#else
#error "chip_select.h: CH32v3xx_CHIP must be 303 or 307"
#endif

#endif
