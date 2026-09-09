ENTRY( _start )

/* CH32V203 D6 (CH32V203 F8/G8/K8/C8 — 64K parts; F6/G6/K6/C6 — 32K parts).
 *
 * The die actually carries 256K of flash: 224K user-visible + 28K boot + 4K
 * option/vendor. The user 224K is split by access speed (a separate flash die,
 * see the CH32V20x RM "Flash" section / the CH32V203 decap notes):
 *
 *   FLASH     0x00000000 + 64K   zero-wait  ("R0WAIT" / documented capacity),
 *                                 full speed even at 144 MHz — put code here
 *   SLOWFLASH 0x00010000 + 160K  non-zero-wait, ~10x slower reads, still XIP
 *                                 and programmable — rodata / bulk const data
 *
 * Total user flash 0x00000000..0x00038000 (224K). Same idea as the V303/V307
 * scripts in soc/v30x/Ld/. OpenOCD needs `wch_riscv unfreeze` before writing
 * past 0x10000 — flash.ps1 / the MCP `flash` already issue it.
 *
 * 32K parts (C6/F6/G6/K6): the zero-wait window is 32K — set FLASH LENGTH = 32K
 * and SLOWFLASH ORIGIN = 0x00008000, LENGTH = 192K.
 */
__stack_size = 2048;

PROVIDE( _stack_size = __stack_size );

MEMORY
{
	FLASH     (rx) : ORIGIN = 0x00000000, LENGTH = 64K
	SLOWFLASH (rx) : ORIGIN = 0x00010000, LENGTH = 160K
	RAM       (xrw): ORIGIN = 0x20000000, LENGTH = 20K
}

SECTIONS
{
	.init :
	{
		_sinit = .;
		. = ALIGN(4);
		KEEP(*(SORT_NONE(.init)))
		. = ALIGN(4);
		_einit = .;
	} >FLASH AT>FLASH

	.vector :
	{
		*(.vector);
		. = ALIGN(64);
	} >FLASH AT>FLASH

	.text :
	{
		. = ALIGN(4);
		*(.text)
		*(.text.*)
		*(.gnu.linkonce.t.*)
		. = ALIGN(4);
	} >FLASH AT>FLASH

	.SLOWFLASH :
	{
		. = ALIGN(4);
		*(.rodata)
		*(.rodata*)
		*(.fl_data)
		*(.SLOWFLASH)
		*(.SLOWFLASH.*)
		. = ALIGN(4);
	} >SLOWFLASH AT>SLOWFLASH

	.fini :
	{
		KEEP(*(SORT_NONE(.fini)))
		. = ALIGN(4);
	} >FLASH AT>FLASH

	PROVIDE( _etext = . );
	PROVIDE( _eitcm = . );

	.preinit_array :
	{
		PROVIDE_HIDDEN (__preinit_array_start = .);
		KEEP (*(.preinit_array))
		PROVIDE_HIDDEN (__preinit_array_end = .);
	} >FLASH AT>FLASH

	.init_array :
	{
		PROVIDE_HIDDEN (__init_array_start = .);
		KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
		KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
		PROVIDE_HIDDEN (__init_array_end = .);
	} >FLASH AT>FLASH

	.fini_array :
	{
		PROVIDE_HIDDEN (__fini_array_start = .);
		KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
		KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
		PROVIDE_HIDDEN (__fini_array_end = .);
	} >FLASH AT>FLASH

	.ctors :
	{
		KEEP (*crtbegin.o(.ctors))
		KEEP (*crtbegin?.o(.ctors))
		KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))
		KEEP (*(SORT(.ctors.*)))
		KEEP (*(.ctors))
	} >FLASH AT>FLASH

	.dtors :
	{
		KEEP (*crtbegin.o(.dtors))
		KEEP (*crtbegin?.o(.dtors))
		KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))
		KEEP (*(SORT(.dtors.*)))
		KEEP (*(.dtors))
	} >FLASH AT>FLASH

	.dalign :
	{
		. = ALIGN(4);
		PROVIDE(_data_vma = .);
	} >RAM AT>FLASH

	.dlalign :
	{
		. = ALIGN(4);
		PROVIDE(_data_lma = .);
	} >FLASH AT>FLASH

	.data :
	{
		*(.gnu.linkonce.r.*)
		*(.data .data.*)
		*(.gnu.linkonce.d.*)
		. = ALIGN(8);
		PROVIDE( __global_pointer$ = . + 0x800 );
		*(.sdata .sdata.*)
		*(.sdata2.*)
		*(.gnu.linkonce.s.*)
		. = ALIGN(8);
		*(.srodata.cst16)
		*(.srodata.cst8)
		*(.srodata.cst4)
		*(.srodata.cst2)
		*(.srodata .srodata.*)
		. = ALIGN(4);
		PROVIDE( _edata = .);
	} >RAM AT>FLASH

	.bss :
	{
		. = ALIGN(4);
		PROVIDE( _sbss = .);
		*(.sbss*)
		*(.gnu.linkonce.sb.*)
		*(.bss*)
		*(.gnu.linkonce.b.*)
		*(COMMON*)
		. = ALIGN(4);
		PROVIDE( _ebss = .);
	} >RAM AT>FLASH

	PROVIDE( _end = _ebss);
	PROVIDE( end = . );

	.stack ORIGIN(RAM) + LENGTH(RAM) - __stack_size :
	{
		PROVIDE( _heap_end = . );
		. = ALIGN(4);
		PROVIDE(_susrstack = . );
		. = . + __stack_size;
		PROVIDE( _eusrstack = .);
	} >RAM
}
