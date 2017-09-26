;=======================================================================================================================
;
;	File:		os.asm
;
;	Project:	os.001
;
;	Description:	This sample program defines a valid boot sector that displays a message and waits for a key
;			to be pressed to restart the system. Using assembly directives, either a simple boot sector
;			or an entire floppy disk image is generated. Real mode BIOS interrupts are used to display
;			the message and poll for a keypress.
;
;	Revised:	July 1, 2017
;
;	Assembly:	nasm os.asm -f bin -o os.dat -l os.dat.lst -DBUILDBOOT
;			nasm os.asm -f bin -o os.dsk -l os.dsk.lst -DBUILDDISK
;
;	Assembler:	Netwide Assembler (NASM) 2.13.01
;
;			Copyright (C) 2010-2017 by David J. Walling. All Rights Reserved.
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;	Assembly Directives
;
;	Use one of the following as an assembly directive (-D) with NASM.
;
;	BUILDBOOT	Creates os.dat, a 512-byte boot sector as a standalone file.
;	BUILDDISK	Creates os.dsk, a 1.44MB (3.5") floppy disk image file.
;
;-----------------------------------------------------------------------------------------------------------------------
%ifdef BUILDDISK
%define BUILDBOOT
%endif
;-----------------------------------------------------------------------------------------------------------------------
;
;	Conventions
;
;	Labels:		Labels within a routine are numeric and begin with a period (.10, .20).
;			Labels within a routine begin at ".10" and increment by 10.
;
;	Comments:	A comment that spans the entire line begins with a semicolon in column 1.
;			A comment that accompanies code on a line begins with a semicolon in column 81.
;			Register names in comments are in upper case.
;			Hexadecimal values in comments are in lower case.
;			Routines are preceded with a comment box that includes the routine name, description, and
;			register contents on entry and exit.
;
;	Alignment:	Assembly instructions (mnemonics) begin in column 25.
;			Assembly operands begin in column 33.
;			Lines should not extend beyond column 120.
;
;	Routines:	Routine names are in mixed case (GetYear, ReadRealTimeClock).
;			Routine names begin with a verb (Get, Read, etc.).
;			Routines should have a single entry address and a single exit instruction (ret, iretd, etc.).
;
;	Constants:	Symbolic constants (equates) are named in all-caps beginning with 'E' (EDATAPORT).
;			Constant stored values are named in camel case, starting with 'c'.
;			The 2nd letter of the constant label indicates the storage type.
;
;			cq......	constant quad-word (dq)
;			cd......	constant double-word (dd)
;			cw......	constant word (dw)
;			cb......	constant byte (db)
;			cz......	constant ASCIIZ (null-terminated) string
;
;	Variables:	Variables are named in camel case, starting with 'w'.
;			The 2nd letter of the variable label indicates the storage type.
;
;			wq......	variable quad-word (resq)
;			wd......	variable double-word (resd)
;			ww......	variable word (resw)
;			wb......	variable byte (resb)
;
;	Literals:	Literal values defined by external standards should be defined as symbolic constants (equates).
;			Hexadecimal literals in code are in upper case with a leading '0' and trailing 'h'. e.g. 01Fh.
;			Binary literal values in source code are encoded with a final 'b', e.g. 1010b.
;			Decimal literal values in source code are strictly numerals, e.g. 2048.
;			Octal literal values are avoided.
;			String literals are enclosed in double quotes, e.g. "Loading OS".
;			Single character literals are enclosed in single quotes, e.g. 'A'.
;
;	Structures:	Structure names are in all-caps (DATETIME).
;			Structure names do not begin with a verb.
;
;	Macros:		Macro names are in camel case (getDateString).
;			Macro names do begin with a verb.
;
;	Registers:	Register names in comments are in upper case.
;			Register names in source code are in lower case.
;
;	Usage:		Registers EBX, ECX, ESI, EDI, EBP, SS, CS, DS and ES are preserved by all OS routines.
;			Registers EAX and ECX are preferred for returning response/result values.
;			Register EBX is preferred for passing a context (structure) address parameter.
;			Registers EAX, EDX, ECX and EBX are preferred for passing integral parameters.
;
;-----------------------------------------------------------------------------------------------------------------------
;=======================================================================================================================
;
;	Equates
;
;	The equate (equ) statement defines a symbolic name for a fixed value so that such a value can be defined and
;	verified once and then used throughout the code. Using symbolic names simplifies searching for where logical
;	values are used. Equate names are in all-caps and begin with the letter 'E'. Equates are grouped into related
;	sets. Hardware-based values are listed first, followed by BIOS, protocol and application values.
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;	8042 Keyboard Controller						EKEYB...
;
;	The 8042 Keyboard Controller (8042) is a programmable controller that accepts input signals from the keyboard
;	device. It also signals a hardware interrupt to the CPU when the low-order bit of I/O port 64h is set to zero.
;
;-----------------------------------------------------------------------------------------------------------------------
EKEYBPORTSTAT		equ	064h						;status port
EKEYBCMDRESET		equ	0FEh						;reset bit 0 to restart system
;-----------------------------------------------------------------------------------------------------------------------
;
;	BIOS Interrupts and Functions						EBIOS...
;
;	Basic Input/Output System (BIOS) functions are grouped and accessed by issuing an interrupt call. Each
;	BIOS interrupt supports several funtions. The function code is typically passed in the AH register.
;
;-----------------------------------------------------------------------------------------------------------------------
EBIOSINTVIDEO		equ	010h						;video services interrupt
EBIOSFNSETVMODE		equ	000h						;video set mode function
EBIOSMODETEXT80		equ	003h						;video mode 80x25 text
EBIOSFNTTYOUTPUT	equ	00Eh						;video TTY output function
EBIOSINTKEYBOARD	equ	016h						;keyboard services interrupt
EBIOSFNKEYSTATUS	equ	001h						;keyboard status function
;-----------------------------------------------------------------------------------------------------------------------
;
;	Boot Sector and Loader Constants					EBOOT...
;
;	Equates in this section support the boot sector and the 16-bit operating system loader, which will be
;	responsible for placing the CPU into protected mode and calling the initial operating system task.
;
;-----------------------------------------------------------------------------------------------------------------------
EBOOTSTACKTOP		equ	0100h						;boot sector stack top relative to DS
EBOOTSECTORBYTES	equ	512						;bytes per sector
EBOOTDISKSECTORS	equ	2880						;sectors per disk
EBOOTDISKBYTES		equ	(EBOOTSECTORBYTES*EBOOTDISKSECTORS)		;bytes per disk
%ifdef BUILDBOOT
;=======================================================================================================================
;
;	Boot Sector								@disk: 000000	@mem: 007c00
;
;	The first sector of the disk is the boot sector. The BIOS will load the boot sector into memory and pass
;	control to the code at the start of the sector. The boot sector code is responsible for loading the operating
;	system into memory. The boot sector contains a disk parameter table describing the geometry and allocation
;	of the disk. Following the disk parameter table is code to load the operating system kernel into memory.
;
;	The 'cpu' directive limits emitted code to those instructions supported by the most primitive processor
;	we expect to ever execute our code. The 'vstart' parameter indicates addressability of symbols so as to
;	emulating the DOS .COM program model. Although the BIOS is expected to load the boot sector at address 7c00,
;	we do not make that assumption. The CPU starts in 16-bit addressing mode. A three-byte jump instruction is
;	immediately followed by a disk parameter table.
;
;=======================================================================================================================
			cpu	8086						;assume minimal CPU
section			boot	vstart=0100h					;emulate .COM (CS,DS,ES=PSP) addressing
			bits	16						;16-bit code at power-up
Boot			jmp	word Boot.10					;jump over parameter table
;-----------------------------------------------------------------------------------------------------------------------
;
;	Disk Parameter Table
;
;	The disk parameter table informs the BIOS of the floppy disk architecture. Here, we use parameters for the
;	3.5" 1.44MB floppy disk since this format is widely supported by virtual machine hypervisors.
;
;-----------------------------------------------------------------------------------------------------------------------
			db	"CustomOS"					;eight-byte label
cwSectorBytes		dw	EBOOTSECTORBYTES				;bytes per sector
cbClusterSectors	db	1						;sectors per cluster
cwReservedSectors	dw	1						;reserved sectors
cbFatCount		db	2						;file allocation table copies
cwDirEntries		dw	224						;max directory entries
cwDiskSectors		dw	EBOOTDISKSECTORS				;sectors per disk
cbDiskType		db	0F0h						;1.44MB
cwFatSectors		dw	9						;sectors per FAT copy
cbTrackSectors		equ	$						;sectors per track (as byte)
cwTrackSectors		dw	18						;sectors per track (as word)
cwDiskSides		dw	2						;sides per disk
cwSpecialSectors	dw	0						;special sectors
;
;	BIOS typically loads the boot sector at absolute address 7c00 and sets the stack pointer at 512 bytes past the
;	end of the boot sector. But, since BIOS code varies, we don't make any assumptions as to where our boot sector
;	is loaded. For example, the initial CS:IP could be 0:7c00, 700:c00, 7c0:0, etc. So, to avoid assumptions, we
;	first normalize CS:IP to get the absolute segment address in BX. The comments below show the effect of this code
;	given several possible starting values for CS:IP.
;
										;CS:IP	 0:7c00 700:c00 7c0:0
Boot.10			call	word .20					;[ESP] =   7c21     c21    21
.@20			equ	$-$$						;.@20 = 021h
.20			pop	ax						;AX =	   7c21     c21    21
			sub	ax,.@20						;BX =	   7c00     c00     0
			mov	cl,4						;shift count
			shr	ax,cl						;AX =	    7c0      c0     0
			mov	bx,cs						;BX =	      0     700   7c0
			add	bx,ax						;BX =	    7c0     7c0   7c0
;
;	Now, since we are assembling our boot code to emulate the addressing of a .COM file, we want the DS and ES
;	registers to be set to where a Program Segment Prefix (PSP) would be, exactly 100h (256) bytes prior to
;	the start of our code. This will correspond to our assembled data address offsets. Note that we instructed
;	the assembler to produce addresses for our symbols that are offset from our code by 100h. See the "vstart"
;	parameter for the "section" directive above. We also set SS to the PSP and SP to the address of our i/o
;	buffer. This leaves 256 bytes of usable stack from 7b0:300 to 7b0:400.
;
			sub	bx,16						;BX = 07b0
			mov	ds,bx						;DS = 07b0 = psp
			mov	es,bx						;ES = 07b0 = psp
			mov	ss,bx						;SS = 07b0 = psp (ints disabled)
			mov	sp,EBOOTSTACKTOP				;SP = 0100       (ints enabled)
;
;	Our boot addressability is now set up according to the following diagram.
;
;	DS,ES,SS ----->	007b00	+-----------------------------------------------+ DS:0000
;				|  Boot Stack & Boot PSP (Unused)		|
;				|  256 = 100h bytes				|
;	SS:SP -------->	007c00	+-----------------------------------------------+ DS:0100  07b0:0100
;				|  Boot Sector (vstart=0100h)			|
;				|  1 sector = 512 = 200h bytes			|
;			007e00	+-----------------------------------------------+ DS:0300
;
;	Set the video mode to 80 column, 25 row, text.
;
			mov	ax,EBIOSFNSETVMODE<<8|EBIOSMODETEXT80		;set mode function, 80x25 text mode
			int	EBIOSINTVIDEO					;call BIOS display interrupt
;
;	Write a message to the console so we know we have our addressability established.
;
			mov	si,czStartingMsg				;starting message
			call	PutTTYString					;display loader message
;
;	Now we want to wait for a keypress. We can use a keyboard interrupt function for this (INT 16h, AH=0).
;	However, some hypervisor BIOS implementations have been seen to implement the "wait" as simply a fast
;	iteration of the keyboard status function call (INT 16h, AH=1), causing a CPU race condition. So, instead
;	we will use the keyboard status call and iterate over a halt (HLT) instruction until a key is pressed.
;	By convention, we enable maskable interrupts with STI before issuing HLT, so as not to catch fire.
;
.30			mov	ah,EBIOSFNKEYSTATUS				;keyboard status function
			int	EBIOSINTKEYBOARD				;call BIOS keyboard interrupt
			jnz	.40						;exit if key pressed
			sti							;enable maskable interrupts
			hlt							;wait for interrupt
			jmp	.30						;repeat until keypress
;
;	Now that a key has been pressed, we signal the system to restart by driving the B0 line on the 8042
;	keyboard controller low (OUT 64h,0feh). The restart may take some microseconds to kick in, so we issue
;	HLT until the system resets.
;
.40			mov	al,EKEYBCMDRESET				;8042 pulse output port pin
			out	EKEYBPORTSTAT,al				;drive B0 low to restart
.50			sti							;enable maskable interrupts
			hlt							;stop until reset, int, nmi
			jmp	.50						;loop until restart kicks in
;-----------------------------------------------------------------------------------------------------------------------
;
;	Routine:	PutTTYString
;
;	Description:	This routine sends a NUL-terminated string of characters to the TTY output device. We use the
;			TTY output function of the BIOS video interrupt, passing the address of the string in DS:SI
;			and the BIOS teletype function code in AH. After a return from the BIOS interrupt, we repeat
;			for the next string character until a NUL is found. Note that we clear the direction flag (DF)
;			with CLD before each LODSB. This is just in case the direction flag is ever returned as set
;			by the video interrupt. This is a precaution since a well-written BIOS should preserve all
;			registers and flags unless used to indicate return status.
;
;	In:		DS:SI	address of string
;
;-----------------------------------------------------------------------------------------------------------------------
PutTTYString		cld							;forward strings
			lodsb							;load next byte at DS:SI in AL
			test	al,al						;end of string?
			jz	.10						;... yes, exit our loop
			mov	ah,EBIOSFNTTYOUTPUT				;BIOS teletype function
			int	EBIOSINTVIDEO					;call BIOS display interrupt
			jmp	PutTTYString					;repeat until done
.10			ret							;return
;-----------------------------------------------------------------------------------------------------------------------
;
;	Loader Data
;
;	Our only "data" is the string displayed when system starts. It ends with ASCII carriage-return (13) and line-
;	feed (10) values. The remainder of the boot sector is filled with NUL. The boot sector finally ends with the
;	required two-byte signature checked by the BIOS. Note that recent versions of NASM will issue a warning if
;	the calculated address for the end-of-sector signature produces a negative value for "510-($-$$)". This will
;	indicate if we have added too much data and exceeded the length of the sector.
;
;-----------------------------------------------------------------------------------------------------------------------
czStartingMsg		db	"Starting OS",13,10,0				;starting message
			times	510-($-$$) db 0h				;zero fill to end of sector
			db	055h,0AAh					;end of sector signature
%endif
%ifdef BUILDDISK
;-----------------------------------------------------------------------------------------------------------------------
;
;	Free Disk Space								@disk: 000200	@mem:  n/a
;
;	Following the convention introduced by DOS, we use the value 'F6' to indicate unused floppy disk storage.
;
;-----------------------------------------------------------------------------------------------------------------------
section			unused							;unused disk space
			times 	EBOOTDISKBYTES-0200h db 0F6h			;fill to end of disk image
%endif
;=======================================================================================================================
;
;	End of Program Code
;
;=======================================================================================================================
