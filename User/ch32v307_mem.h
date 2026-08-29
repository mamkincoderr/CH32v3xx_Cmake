/********************************** (C) COPYRIGHT *******************************
 * File Name          : ch32v307_mem.h
 * Author             : mamkincoderr
 *                      https://github.com/mamkincoderr
 *                      https://t.me/oDeXteRo
 * Description        : CH32V307 RAM_CODE_MOD (4 CODE/RAM splits).
 *                      Hand-edit CH32V307_MEM below to pick the mode.
 *                      Ignored on CH32V303 (see chip_select.h).
 *                      CMake reads this file (regex) to build the matching
 *                      Link_ch32v307.ld MEMORY map.
 *******************************************************************************/
#ifndef CH32V307_MEM_H
#define CH32V307_MEM_H

/* FLASH_OBR RAM_CODE_MOD — 2 bits, 4 modes. CODE+SRAM window = 320K.
   Physical flash 480K. Addresses >= 0x20000 are wait-state (SLOWFLASH). */
#define MEM192_128  0b001   /* CODE 192K + RAM 128K */
#define MEM224_96   0b011   /* CODE 224K + RAM  96K */
#define MEM256_64   0b101   /* CODE 256K + RAM  64K */
#define MEM288_32   0b111   /* CODE 288K + RAM  32K  (EVT default) */

/* Pick one: MEM192_128, MEM224_96, MEM256_64 or MEM288_32. */
#define CH32V307_MEM  MEM288_32

void MemConfig(void);

#endif
