/*--------------------------------------------------------------------------------
	This Source Code Form is subject to the terms of the Mozilla Public License,
	v. 2.0. If a copy of the MPL was not distributed with this file, You can
	obtain one at https://mozilla.org/MPL/2.0/.
--------------------------------------------------------------------------------*/
OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

__ewram_end	=	ORIGIN(ewram) + LENGTH(ewram);
__eheap_end	=	ORIGIN(ewram) + LENGTH(ewram);

__dtcm_top	=	ORIGIN(dtcm) + LENGTH(dtcm);
__irq_flags	=	__dtcm_top - 0x08;
__irq_vector	=	__dtcm_top - 0x04;

__sp_svc	=	__dtcm_top - 0x100;
__sp_irq	=	__sp_svc - 0x100;
__sp_usr	=	__sp_irq - 0x100;

PHDRS {
	main    PT_LOAD FLAGS(7);
	dtcm    PT_LOAD FLAGS(7);
	itcm    PT_LOAD FLAGS(7);
	vectors PT_LOAD FLAGS(7);
	twl     PT_LOAD FLAGS(0x100007);
}

SECTIONS
{
	/* Secure area crap */
	.secure : { *(.secure) } >ewram :main = 0

	.crt0	:
	{
		__text_start = . ;
		KEEP (*(.crt0))
		. = ALIGN(4);  /* REQUIRED. LD is flaky without it. */
	} >ewram :main = 0x00

	.plt : { *(.plt) } >ewram :main = 0xff

	.init :
	{
		KEEP (*(SORT_NONE(.init)))
	} >ewram :main

	.text :   /* ALIGN (4): */
	{
		*(EXCLUDE_FILE(*.itcm* *.vectors* *.twl*) .text)
		*(EXCLUDE_FILE(*.itcm* *.vectors* *.twl*) .stub)
		*(EXCLUDE_FILE(*.itcm* *.vectors* *.twl*) .text.*)
		/* .gnu.warning sections are handled specially by elf32.em.  */
		*(EXCLUDE_FILE(*.twl*) .gnu.warning)
		*(EXCLUDE_FILE(*.twl*) .gnu.linkonce.t*)
		*(.glue_7)
		*(.glue_7t)
		. = ALIGN(4);  /* REQUIRED. LD is flaky without it. */
	} >ewram :main = 0xff

	.fini           :
	{
		KEEP (*(.fini))
	} >ewram :main =0xff

	__text_end = . ;

	.rodata :
	{
		*(EXCLUDE_FILE(*.twl*) .rodata)
		*all.rodata*(*)
		*(EXCLUDE_FILE(*.twl*) .roda)
		*(EXCLUDE_FILE(*.twl*) .rodata.*)
		*(EXCLUDE_FILE(*.twl*) .gnu.linkonce.r*)
		SORT(CONSTRUCTORS)
		. = ALIGN(4);   /* REQUIRED. LD is flaky without it. */
	} >ewram :main = 0xff

	.ARM.extab   : { *(.ARM.extab* .gnu.linkonce.armextab.*) } >ewram :main
 	__exidx_start = .;
	ARM.exidx   : { *(.ARM.exidx* .gnu.linkonce.armexidx.*) } >ewram :main
 	__exidx_end = .;

	/*	Ensure the __preinit_array_start label is properly aligned.  We
		could instead move the label definition inside the section, but
		the linker would then create the section even if it turns out to
		be empty, which isn't pretty.  */

	. = ALIGN(32 / 8);

	PROVIDE (__preinit_array_start = .);
	.preinit_array     : { KEEP (*(.preinit_array)) } >ewram :main = 0xff
	PROVIDE (__preinit_array_end = .);
	PROVIDE (__init_array_start = .);
	.init_array     :
	{
		KEEP (*(SORT(.init_array.*)))
		KEEP (*(.init_array))
	} >ewram :main = 0xff
	PROVIDE (__init_array_end = .);
	PROVIDE (__fini_array_start = .);
	.fini_array     :
	{
		KEEP (*(.fini_array))
		KEEP (*(SORT(.fini_array.*)))
	} >ewram :main = 0xff

	PROVIDE (__fini_array_end = .);

	.ctors :
	{
	/*	gcc uses crtbegin.o to find the start of the constructors, so
		we make sure it is first.  Because this is a wildcard, it
		doesn't matter if the user does not actually link against
		crtbegin.o; the linker won't look for a file to match a
		wildcard.  The wildcard also means that it doesn't matter which
		directory crtbegin.o is in.  */
		KEEP (*crtbegin.o(.ctors))
		KEEP (*(EXCLUDE_FILE (*crtend.o) .ctors))
		KEEP (*(SORT(.ctors.*)))
		KEEP (*(.ctors))
		. = ALIGN(4);   /* REQUIRED. LD is flaky without it. */
	} >ewram :main = 0xff

	.dtors :
	{
		KEEP (*crtbegin.o(.dtors))
		KEEP (*(EXCLUDE_FILE (*crtend.o) .dtors))
		KEEP (*(SORT(.dtors.*)))
		KEEP (*(.dtors))
		. = ALIGN(4);   /* REQUIRED. LD is flaky without it. */
	} >ewram :main = 0xff

	.eh_frame :
	{
		KEEP (*(.eh_frame))
		. = ALIGN(4);   /* REQUIRED. LD is flaky without it. */
	} >ewram :main = 0xff

	.gcc_except_table :
	{
		*(.gcc_except_table)
		. = ALIGN(4);   /* REQUIRED. LD is flaky without it. */
	} >ewram :main = 0xff
	.jcr            : { KEEP (*(.jcr)) } >ewram :main = 0
	.got            : { *(.got.plt) *(.got) *(.rel.got) } >ewram :main = 0

	.ewram ALIGN(4) : 
	{
		__ewram_start = ABSOLUTE(.) ;
		*(.ewram)
		*ewram.*(.text)
		. = ALIGN(4);   /* REQUIRED. LD is flaky without it. */
	} >ewram :main = 0xff


	.data ALIGN(4) :
	{
		__data_start = ABSOLUTE(.);
		*(EXCLUDE_FILE(*.twl*) .data)
		*(EXCLUDE_FILE(*.twl*) .data.*)
		*(EXCLUDE_FILE(*.twl*) .gnu.linkonce.d*)
		CONSTRUCTORS
		. = ALIGN(4);
	} >ewram :main = 0xff

	/* The thread control block must be aligned to at least 8 bytes */
	.tdata ALIGN(8) :
	{
		__tdata_start = ABSOLUTE(.) ;
		*(.tdata .tdata.* .gnu.linkonce.td.*)
		. = ALIGN(4) ;
		__tdata_end = ABSOLUTE(.) ;
		__data_end = . ;
	} >ewram :main = 0xff

	__tdata_size = __tdata_end - __tdata_start ;

	__bss_vma = . ;

	.dtcm :
	{
		__dtcm_lma = LOADADDR(.dtcm);
		__dtcm_start = ABSOLUTE(.);
		*(.dtcm)
		*(.dtcm.*)
		. = ALIGN(4);
		__dtcm_end = ABSOLUTE(.);
	} >dtcm AT>ewram :dtcm = 0xff

	.itcm :
	{
		__itcm_lma = LOADADDR(.itcm);
		__itcm_start = ABSOLUTE(.);
		*(.itcm)
		*.itcm*(.text .stub .text.*)
		. = ALIGN(4);
		__itcm_end = ABSOLUTE(.);
	} >itcm AT>ewram :itcm = 0xff

	.vectors :
	{
		__vectors_lma = LOADADDR(.vectors);
		__vectors_start = ABSOLUTE(.);
		KEEP(*(.vectors .vectors.*))
		. = ALIGN(4);
		__vectors_end = ABSOLUTE(.);
	} >vectors AT>ewram :vectors = 0xff
	
	.sbss __dtcm_end (NOLOAD): 
	{
		__sbss_start = ABSOLUTE(.);
		__sbss_start__ = ABSOLUTE(.);
		*(.sbss)
		. = ALIGN(4);    /* REQUIRED. LD is flaky without it. */
		__sbss_end = ABSOLUTE(.);
	} >dtcm :NONE

	.bss __bss_vma (NOLOAD): 
	{
		__bss_start = ABSOLUTE(.);
		__bss_start__ = ABSOLUTE(.);
		*(EXCLUDE_FILE(*.twl*) .dynbss)
		*(EXCLUDE_FILE(*.twl*) .gnu.linkonce.b*)
		*(EXCLUDE_FILE(*.twl*) .bss*)
		*(EXCLUDE_FILE(*.twl*) COMMON)
		. = ALIGN(4);    /* REQUIRED. LD is flaky without it. */
		__bss_end__ = ABSOLUTE(.) ;
	} >ewram :NONE

	.tls ALIGN(8) (NOLOAD) :
	{
		__tls_start = ABSOLUTE(.) ;

		/* Reserve space for .tdata */
		. = . + __tdata_size;
		. = ALIGN(4) ;

		/* Allocate all tbss symbols */
		 __tbss_start = ABSOLUTE(.) ;
		*(.tbss .tbss.* .gnu.linkonce.tb.*)
		*(.tcommon)
		 __tbss_end = ABSOLUTE(.) ;

		 __tls_end = ABSOLUTE(.) ;

		__end__ = ABSOLUTE(.) ;
	} >ewram :NONE

	__tbss_size = __tbss_end - __tbss_start;

	.twl __end__ : AT(MAX(0x2400000,MAX(__end__,LOADADDR(.vectors)+SIZEOF(.vectors))))
	{
		__arm9i_lma__ = LOADADDR(.twl);
		__arm9i_start__ = ABSOLUTE(.);
		*(.twl)
		*.twl*(.text .stub .text.* .gnu.linkonce.t.*)
		*.twl*(.rodata)
		*.twl*(.roda)
		*.twl*(.rodata.*)
		*.twl*(.data)
		*.twl*(.data.*)
		*.twl*(.gnu.linkonce.d*)
		__arm9i_end__ = ABSOLUTE(.);
	} :twl

	.twl_bss __arm9i_end__ (NOLOAD):
	{
		__twl_bss_start__ = ABSOLUTE(.);
		*(.twl_bss)
		*.twl*(.dynbss)
		*.twl*(.gnu.linkonce.b*)
		*.twl*(.bss*)
		*.twl*(COMMON)
		. = ALIGN(4);    /* REQUIRED. LD is flaky without it. */
		__twl_bss_end__ = ABSOLUTE(.);
		__twl_end__ = ABSOLUTE(.);
	} :NONE

	/* Stabs debugging sections.  */
	.stab 0 : { *(.stab) }
	.stabstr 0 : { *(.stabstr) }
	.stab.excl 0 : { *(.stab.excl) }
	.stab.exclstr 0 : { *(.stab.exclstr) }
	.stab.index 0 : { *(.stab.index) }
	.stab.indexstr 0 : { *(.stab.indexstr) }
	.comment 0 : { *(.comment) }
	/*	DWARF debug sections.
		Symbols in the DWARF debugging sections are relative to the beginning
		of the section so we begin them at 0.  */
	/* DWARF 1 */
	.debug          0 : { *(.debug) }
	.line           0 : { *(.line) }
	/* GNU DWARF 1 extensions */
	.debug_srcinfo  0 : { *(.debug_srcinfo) }
	.debug_sfnames  0 : { *(.debug_sfnames) }
	/* DWARF 1.1 and DWARF 2 */
	.debug_aranges  0 : { *(.debug_aranges) }
	.debug_pubnames 0 : { *(.debug_pubnames) }
	/* DWARF 2 */
	.debug_info     0 : { *(.debug_info) }
	.debug_abbrev   0 : { *(.debug_abbrev) }
	.debug_line     0 : { *(.debug_line) }
	.debug_frame    0 : { *(.debug_frame) }
	.debug_str      0 : { *(.debug_str) }
	.debug_loc      0 : { *(.debug_loc) }
	.debug_macinfo  0 : { *(.debug_macinfo) }
	/* SGI/MIPS DWARF 2 extensions */
	.debug_weaknames 0 : { *(.debug_weaknames) }
	.debug_funcnames 0 : { *(.debug_funcnames) }
	.debug_typenames 0 : { *(.debug_typenames) }
	.debug_varnames  0 : { *(.debug_varnames) }
	.stack 0x80000 : { _stack = .; *(.stack) }
	/* These must appear regardless of  .  */
}
