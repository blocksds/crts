/*--------------------------------------------------------------------------------
	This Source Code Form is subject to the terms of the Mozilla Public License,
	v. 2.0. If a copy of the MPL was not distributed with this file, You can
	obtain one at https://mozilla.org/MPL/2.0/.
--------------------------------------------------------------------------------*/

@---------------------------------------------------------------------------------
@ DS processor selection
@---------------------------------------------------------------------------------
	.arch	armv5te
	.cpu	arm946e-s
@---------------------------------------------------------------------------------

	.equ	_libnds_argv,0x02FFFE70

@---------------------------------------------------------------------------------
	.section ".crt0","ax"
	.global _start
@---------------------------------------------------------------------------------
	.align	4
	.arm
@---------------------------------------------------------------------------------
_start:
@---------------------------------------------------------------------------------
	mov	r0, #0x04000000		@ IME = 0;
	str	r0, [r0, #0x208]
	
	@ set sensible stacks to allow bios call

	mov	r0, #0x13		@ Switch to SVC Mode
	msr	cpsr, r0
	mov	r1,#0x03000000
	sub	r1,r1,#0x1000
	mov	sp,r1
	mov	r0, #0x1F		@ Switch to System Mode
	msr	cpsr, r0
	sub	r1,r1,#0x100
	mov	sp,r1

	ldr	r3, =__libnds_mpu_setup
	blx	r3

	mov	r0, #0x12		@ Switch to IRQ Mode
	msr	cpsr, r0
	ldr	sp, =__sp_irq		@ Set IRQ stack

	mov	r0, #0x13		@ Switch to SVC Mode
	msr	cpsr, r0
	ldr	sp, =__sp_svc		@ Set SVC stack

	mov	r0, #0x1F		@ Switch to System Mode
	msr	cpsr, r0
	ldr	sp, =__sp_usr		@ Set user stack

	mov	r12, #0x4000000		@ Read system ROM status (NTR/TWL)
	ldrb	r11, [r12,r12,lsr #12]
	and	r11, r11, #0x3

	mov	r9, #(0x0<<8)		@ Synchronize with ARM7
	str	r9, [r12, #0x180]
	mov	r9, #0x9
	bl	IPCSync
	mov	r9, #(0xA<<8)
	str	r9, [r12, #0x180]
	mov	r9, #0xB
	bl	IPCSync
	mov	r9, #(0xC<<8)
	str	r9, [r12, #0x180]
	mov	r9, #0xD
	bl	IPCSync
	mov	r9, r11, lsl #8
	str	r9, [r12, #0x180]
	mov	r9, #0
	bl	IPCSync
	str	r9, [r12, #0x180]

	ldr	r1, =__itcm_lma		@ Copy instruction tightly coupled memory (itcm section) from LMA to VMA
	ldr	r2, =__itcm_start
	ldr	r4, =__itcm_end
	bl	CopyMemCheck

	ldr	r1, =__vectors_lma	@ Copy reserved vectors area (itcm section) from LMA to VMA
	ldr	r2, =__vectors_start
	ldr	r4, =__vectors_end
	bl	CopyMemCheck

	ldr	r1, =__dtcm_lma		@ Copy data tightly coupled memory (dtcm section) from LMA to VMA
	ldr	r2, =__dtcm_start
	ldr	r4, =__dtcm_end
	bl	CopyMemCheck

	cmp	r11, #1
	ldrne	r10, =__end__		@ (DS mode) heap start
	ldreq	r10, =__twl_end__	@ (DSi mode) heap start
	bl	checkARGV		@ check and process argv trickery

	ldr	r0, =__bss_start__	@ Clear BSS section
	ldr	r1, =__bss_end__
	sub	r1, r1, r0
	bl	ClearMem

	ldr	r0, =__sbss_start	@ Clear SBSS section 
	ldr	r1, =__sbss_end
	sub	r1, r1, r0
	bl	ClearMem

	cmp	r11, #1
	bne	NotTWL
	ldr	r9, =__dsimode		@ set DSi mode flag
	strb	r11, [r9]

	@ Copy TWL area (arm9i section) from LMA to VMA
	ldr	r1, =0x02ffe1c8		@ Get ARM9i LMA from header
	ldr	r1, [r1]

	ldr	r2, =__arm9i_start__
	cmp	r1, r2			@ skip copy if LMA=VMA
	ldrne	r4, =__arm9i_end__
	blne	CopyMemCheck

	ldr	r0, =__twl_bss_start__	@ Clear TWL BSS section
	ldr	r1, =__twl_bss_end__
	sub	r1, r1, r0
	bl	ClearMem

NotTWL:
	ldr	r0, =_libnds_argv

	@ reset heap base
	ldr	r2, [r0,#20]		@ newheap base
	cmp	r2, #0
	moveq	r2, r10
	ldr	r1, =fake_heap_start	@ set heap start
	str	r2, [r1]

	ldr	r1, =fake_heap_end	@ set heap end
	sub	r8, r8,#0xc000
	str	r8, [r1]

	push	{r0}
	ldr	r0, =__secure_area__
	ldr	r3, =initSystem
	blx	r3			@ system initialisation

	ldr	r3, =__libc_init_array	@ global constructors
	blx	r3

	pop	{r0}

	ldr	r1, [r0,#16]		@ argv
	ldr	r0, [r0,#12]		@ argc

	ldr	r3, =cothread_start	@ This starts main as a thread
	ldr	lr, =__libnds_exit
	bx	r3			@ jump to user code

@---------------------------------------------------------------------------------
@ check for a commandline 
@---------------------------------------------------------------------------------
checkARGV:
@---------------------------------------------------------------------------------
	ldr	r0, =_libnds_argv	@ argv structure
	mov	r1, #0
	str	r1, [r0,#12]		@ clear argc
	str	r1, [r0,#16]		@ clear argv
	
	ldr	r3, [r0]		@ argv magic number
	ldr	r2, =0x5f617267		@ '_arg'
	cmp	r3, r2
	strne	r1, [r0,#20]
	bxne	lr			@ bail out if no magic
	
	ldr	r1, [r0, #4]		@ command line address
	ldr	r2, [r0, #8]		@ length of command line

	@ copy to heap
	mov	r3, r10			@ initial heap base
	str	r3, [r0, #4]		@ set command line address

	cmp	r2, #0
	subnes	r4, r3, r1		@ dst-src
	bxeq	lr			@ dst == src || len==0 : nothing to do.
	
	cmphi	r2, r4			@ len > (dst-src)
	bhi	.copybackward

.copyforward:		
	ldrb	r4, [r1], #1
	strb	r4, [r3], #1
	subs	r2, r2, #1
	bne	.copyforward
	b	.copydone

.copybackward:
	subs	r2, r2, #1
	ldrb	r4, [r1, r2]
	strb	r4, [r3, r2]
	bne	.copybackward

.copydone:
	push	{lr}
	ldr	r3, =build_argv
	blx	r3
	pop	{lr}
	bx	lr	


@---------------------------------------------------------------------------------
@ Clear memory to 0x00 if length != 0
@  r0 = Start Address
@  r1 = Length
@---------------------------------------------------------------------------------
ClearMem:
@---------------------------------------------------------------------------------
	mov	r2, #3			@ Round down to nearest word boundary
	add	r1, r1, r2		@ Shouldn't be needed
	bics	r1, r1, r2		@ Clear 2 LSB (and set Z)
	bxeq	lr			@ Quit if copy size is 0

	mov	r2, #0
ClrLoop:
	stmia	r0!, {r2}
	subs	r1, r1, #4
	bne	ClrLoop

	bx	lr

@---------------------------------------------------------------------------------
@ Copy memory if length	!= 0
@  r1 = Source Address
@  r2 = Dest Address
@  r4 = Dest Address + Length
@---------------------------------------------------------------------------------
CopyMemCheck:
@---------------------------------------------------------------------------------
	sub	r3, r4, r2		@ Is there any data to copy?
@---------------------------------------------------------------------------------
@ Copy memory
@  r1 = Source Address
@  r2 = Dest Address
@  r3 = Length
@---------------------------------------------------------------------------------
CopyMem:
@---------------------------------------------------------------------------------
	mov	r0, #3			@ These commands are used in cases where
	add	r3, r3, r0		@ the length is not a multiple of 4,
	bics	r3, r3, r0		@ even though it should be.
	bxeq	lr			@ Length is zero, so exit
CIDLoop:
	ldmia	r1!, {r0}
	stmia	r2!, {r0}
	subs	r3, r3, #4
	bne	CIDLoop

	bx	lr

@---------------------------------------------------------------------------------
@ Synchronize with ARM7
@---------------------------------------------------------------------------------
IPCSync:
@---------------------------------------------------------------------------------
	ldr	r10, [r12, #0x180]
	and	r10, r10, #0xF
	cmp	r10, r9
	bne	IPCSync
	bx	lr

@---------------------------------------------------------------------------------
	.align
	.pool
	.end
@---------------------------------------------------------------------------------
