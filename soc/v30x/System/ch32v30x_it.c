/********************************** (C) COPYRIGHT *******************************
* File Name          : ch32v30x_it.c
* Author             : WCH
* Version            : V1.0.0
* Date               : 2021/06/06
* Description        : Main Interrupt Service Routines.
*********************************************************************************
* Copyright (c) 2021 Nanjing Qinheng Microelectronics Co., Ltd.
* Attention: This software (modified or not) and binary are used for
* microcontroller manufactured by Nanjing Qinheng Microelectronics.
*******************************************************************************/
#include "ch32v30x_it.h"

void NMI_Handler(void) __attribute__((interrupt()));
void HardFault_Handler(void) __attribute__((interrupt()));

volatile uint32_t hf_mepc;
volatile uint32_t hf_mcause;
volatile uint32_t hf_mtval;
volatile uint32_t hf_sp;
volatile uint32_t hf_ra;

/*********************************************************************
 * @fn      NMI_Handler
 *
 * @brief   This function handles NMI exception.
 *
 * @return  none
 */
void NMI_Handler(void)
{
    while (1)
    {
        __disable_irq();
    }
}

/*********************************************************************
 * @fn      HardFault_Handler
 *
 * @brief   This function handles Hard Fault exception.
 *
 * @return  none
 */
void HardFault_Handler(void)
{
    uint32_t mepc, mcause, mtval, sp, ra;

    __asm volatile("csrr %0, mepc" : "=r"(mepc));
    __asm volatile("csrr %0, mcause" : "=r"(mcause));
    __asm volatile("csrr %0, mtval" : "=r"(mtval));
    __asm volatile("mv %0, sp" : "=r"(sp));
    __asm volatile("mv %0, ra" : "=r"(ra));
    hf_mepc = mepc;
    hf_mcause = mcause;
    hf_mtval = mtval;
    hf_sp = sp;
    hf_ra = ra;

    while (1)
    {
    }
}
