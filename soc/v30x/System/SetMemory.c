/********************************** (C) COPYRIGHT *******************************
 * File Name          : SetMemory.c
 * Author             : mamkincoderr
 *                      https://github.com/mamkincoderr
 *                      https://t.me/oDeXteRo
 * Description        : Program CH32V307 USER option byte RAM_CODE_MOD.
 *                      Called from startup_ch32v30x_D8C.S before .data copy.
 *                      Mode is CH32V307_MEM from User/main.c (CMake -D).
 *******************************************************************************/

#include "ch32v30x.h"
#include "ch32v307_mem.h"

#define STANDYRST   1
#define STOPRST     1
#define IWDGSW      1
#define RESERV      0b011
#define USE_RAM     ((uint8_t)CH32V307_MEM)
#define OB1         ((uint8_t)((USE_RAM << 5) | (RESERV << 3) | (STANDYRST << 2) | (STOPRST << 1) | (IWDGSW << 0)))

void MemConfig(void)
{
#ifndef CH32V30x_D8C
    (void)OB1;
    return;
#else
    FLASH->OBKEYR = FLASH_KEYR_KEY1;
    FLASH->OBKEYR = FLASH_KEYR_KEY2;
    FLASH_Unlock();
    uint16_t obr = *((uint16_t *)0x1FFFF802);

    if ((obr & 0x0FF) != OB1)
    {
        FLASH_ProgramOptionByteData(0x1FFFF802, OB1);
        NVIC_SystemReset();
    }
    FLASH_Lock();
#endif
}
