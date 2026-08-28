/********************************** (C) COPYRIGHT *******************************
 * File Name          : main.c
 * Author             : mamkincoderr
 *                      https://github.com/mamkincoderr
 *                      https://t.me/oDeXteRo
 * WCH EVT            : USART_Printf example (debug.c / SPL)
 * Version            : V1.0.0
 * Date               : 2026/08/28
 * Description        : Hello World — USART1 printf (PA9), 115200.
 *
 * Based on official EVT USART_Printf:
 *   https://github.com/openwch/ch32v307/blob/main/EVT/EXAM/USART/USART_Printf/User/main.c
 *
 * USART1_Tx(PB6, remap). Official EVT uses PA9; this board routes
 * WCH-Link SERIAL to the remapped pins (same as DCDC_Cmake uart_pgc).
 *******************************************************************************/

#include "debug.h"

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
    printf("SystemClk:%d\r\n", SystemCoreClock);
    printf("ChipID:%08x\r\n", DBGMCU_GetCHIPID());
#ifdef CH32V30x_D8C
    printf("Chip family: CH32V30x_D8C (CH32V307/305/317)\r\n");
#else
    printf("Chip family: CH32V30x_D8 (CH32V303)\r\n");
#endif

    uint32_t n = 0;
    while (1)
    {
        printf("tick %lu\r\n", (unsigned long)n++);
        Delay_Ms(1000);
    }
}
