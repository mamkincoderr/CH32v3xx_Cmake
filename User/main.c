/********************************** (C) COPYRIGHT *******************************
 * File Name          : main.c
 * Author             : mamkincoderr
 *                      https://github.com/mamkincoderr
 *                      https://t.me/oDeXteRo
 * WCH EVT            : USART_Printf example (debug.c / SPL)
 * Version            : V1.0.0
 * Date               : 2026/08/28
 * Description        : Hello World — USART1 printf, 115200.
 *
 * Based on official EVT USART_Printf:
 *   https://github.com/openwch/ch32v307/blob/main/EVT/EXAM/USART/USART_Printf/User/main.c
 *
 * USART1 TX: CH32V307 = PA9 (EVT, no remap); CH32V303 = PB6 (remap,
 * DCDC / WCH-Link SERIAL). See USART_Printf_Init() in Debug/debug.c.
 *******************************************************************************/

#include "chip_select.h"
#include "debug.h"
#include "ch32v307_mem.h"

/*********************************************************************
 * @fn      main
 *
 * @brief   Hello World. Prints clock, chip ID and a 1 Hz tick on USART1.
 *
 * @return  none
 */

int main(void)
{
    NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);
    SystemCoreClockUpdate();
    Delay_Init();
    USART_Printf_Init(115200);

    printf("Hello World from CH32v3xx_Cmake\r\n");
    printf("Built as %s (CH32v3xx_CHIP=%d)\r\n", CH32v3xx_CHIP_STR, CH32v3xx_CHIP);
    printf("SystemClk:%d\r\n", SystemCoreClock);
    printf("ChipID:%08x\r\n", DBGMCU_GetCHIPID());
#if CH32v3xx_CHIP == 307
    printf("Chip family: CH32V30x_D8C (CH32V307/305/317)\r\n");
#if CH32V307_MEM == MEM288_32
    printf("Flash mode: MEM288_32  CODE 288K + RAM 32K\r\n");
#elif CH32V307_MEM == MEM256_64
    printf("Flash mode: MEM256_64  CODE 256K + RAM 64K\r\n");
#elif CH32V307_MEM == MEM224_96
    printf("Flash mode: MEM224_96  CODE 224K + RAM 96K\r\n");
#elif CH32V307_MEM == MEM192_128
    printf("Flash mode: MEM192_128 CODE 192K + RAM 128K\r\n");
#endif
#elif CH32v3xx_CHIP == 303
    printf("Chip family: CH32V30x_D8 (CH32V303)\r\n");
#else
#error "main.c: CH32v3xx_CHIP must be 303 or 307"
#endif

    uint32_t n = 0;
    while (1)
    {
        printf("tick %lu\r\n", (unsigned long)n++);
        Delay_Ms(1000);
    }
}
