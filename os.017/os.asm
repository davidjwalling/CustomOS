;=======================================================================================================================
;
;       File:           os.asm
;
;       Project:        os.011
;
;       Description:    In this sample, the kernel is expanded to iterate across tasks in a task queue.
;
;       Revised:        July 4, 2018
;
;       Assembly:       nasm os.asm -f bin -o os.dat     -l os.dat.lst     -DBUILDBOOT
;                       nasm os.asm -f bin -o os.dsk     -l os.dsk.lst     -DBUILDDISK
;                       nasm os.asm -f bin -o os.com     -l os.com.lst     -DBUILDCOM
;                       nasm os.asm -f bin -o osprep.com -l osprep.com.lst -DBUILDPREP
;
;       Assembler:      Netwide Assembler (NASM) 2.13.03, Feb 7 2018
;
;       Notice:         Copyright (C) 2010-2018 David J. Walling. All Rights Reserved.
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Assembly Directives
;
;       Use one of the following as an assembly directive (-D) with NASM.
;
;       BUILDBOOT       Creates os.dat, a 512-byte boot sector as a standalone file.
;       BUILDDISK       Creates os.dsk, a 1.44MB (3.5") floppy disk image file.
;       BUILDCOM        Creates os.com, the OS loader and kernel as a standalone DOS program.
;       BUILDPREP       Creates osprep.com, a DOS program that prepares a floppy disk to boot the OS
;
;-----------------------------------------------------------------------------------------------------------------------
%ifdef BUILDDISK                                                                ;if we are building a disk image ...
%define BUILDBOOT                                                               ;... build the boot sector
%define BUILDCOM                                                                ;... and the OS kernel
%endif
%ifdef BUILDPREP                                                                ;if creating the disk prep program ...
%define BUILDBOOT                                                               ;... also build the boot sector
%endif
;-----------------------------------------------------------------------------------------------------------------------
;
;       Conventions
;
;       Alignment:      In this document, columns are numbered beginning with 1.
;                       Assembly instructions (mnemonics) begin in column 25.
;                       Assembly operands begin in column 33.
;                       Inline comments begin in column 81.
;                       Lines should not extend beyond column 120.
;
;       Arguments:      Arguments are passed as registers and generally follow this order: EAX, ECX, EDX, EBX.
;                       However, ECX may be used as the first parameter if a test for zero is required. EBX and EBP
;                       may be used as parameters if the routine is considered a "method" of an "object". In this
;                       case, EBX or EBP will address the object storage. If the routine is general-purpose string
;                       or character-array manipulator, ESI and EDI may be used as parameters to address input and/or
;                       ouput buffers, respectively.
;
;       Code Order:     Routines should appear in the order of their first likely use.
;                       Negative relative call or jump addresses indicate reuse.
;
;       Comments:       A comment that spans the entire line begins with a semicolon in column 1.
;                       A comment that accompanies code on a line begins with a semicolon in column 81.
;                       Register names in comments are in upper case (EAX, EDI).
;                       Hexadecimal values in comments are in lower case (01fh, 0dah).
;                       Routines are preceded with a comment box that includes the routine name, description, and
;                       register contents on entry and exit.
;
;       Constants:      Symbolic constants (equates) are named in all-caps beginning with 'E' (EDATAPORT).
;                       Constant stored values are named in camel case, starting with 'c' (cbMaxLines).
;                       The 2nd letter of the constant label indicates the storage type.
;
;                       cq......        constant quad-word (dq)
;                       cd......        constant double-word (dd)
;                       cw......        constant word (dw)
;                       cb......        constant byte (db)
;                       cz......        constant ASCIIZ (null-terminated) string
;
;       Instructions:   32-bit instructions are generally favored.
;                       8-bit instructions and data are preferred for flags and status fields, etc.
;                       16-bit instructions are avoided wherever possible to avoid prefix bytes.
;
;       Labels:         Labels within a routine are numeric and begin with a period (.10, .20).
;                       Labels within a routine begin at ".10" and increment by 10.
;
;       Literals:       Literal values defined by external standards should be defined as symbolic constants (equates).
;                       Hexadecimal literals in code are in upper case with a leading '0' and trailing 'h' (01Fh).
;                       Binary literal values in source code are encoded with a final 'b' (1010b).
;                       Decimal literal values in source code are strictly numerals (2048).
;                       Octal literal values are avoided.
;                       String literals are enclosed in double quotes, e.g. "Loading OS".
;                       Single character literals are enclosed in single quotes, e.g. 'A'.
;
;       Macros:         Macro names are in camel case, beginning with a lower-case letter (getDateString).
;                       Macro names describe an action and so DO begin with a verb.
;
;       Memory Use:     Operating system memory allocation is avoided wherever possible.
;                       Buffers are kept to as small a size as practicable.
;                       Data and code intermingling is avoided wherever possible.
;
;       Registers:      Register names in comments are in upper case (EAX, EDX).
;                       Register names in source code are in lower case (eax, edx).
;
;       Return Values:  Routines return result values in EAX or ECX or both. Routines should indicate failure by
;                       setting the carry flag to 1. Routines may prefer the use of ECX as a return value if the
;                       value is to be tested for null upon return (using the jecxz instruction).
;
;       Routines:       Routine names are in mixed case, capitalized (GetYear, ReadRealTimeClock).
;                       Routine names begin with a verb (Get, Read, Load).
;                       Routines should have a single entry address and a single exit instruction (ret, iretd, etc.).
;                       Routines that serve as wrappers for library functions carry the same name as the library
;                       function but begin with a leading underscore (_) character.
;
;       Structures:     Structure names are in all-caps (DATETIME).
;                       Structure names describe a "thing" and so do NOT begin with a verb.
;
;       Usage:          Registers EBX, ECX, EBP, SS, CS, DS and ES are preserved by routines.
;                       Registers ESI and EDI are preserved unless they are input parameters.
;                       Registers EAX and ECX are preferred for returning response/result values.
;                       Registers EBX and EBP are preferred for context (structure) address parameters.
;                       Registers EAX, ECX, EDX and EBX are preferred for integral parameters.
;
;       Variables:      Variables are named in camel case, starting with 'w'.
;                       The 2nd letter of the variable label indicates the storage type.
;
;                       wq......        variable quad-word (resq)
;                       wd......        variable double-word (resd)
;                       ww......        variable word (resw)
;                       wb......        variable byte (resb)
;                       ws......        writable structure
;
;-----------------------------------------------------------------------------------------------------------------------
;=======================================================================================================================
;
;       Equates
;
;       The equate (equ) statement defines a symbolic name for a fixed value so that such a value can be defined and
;       verified once and then used throughout the code. Using symbolic names simplifies searching for where logical
;       values are used. Equate names are in all-caps and begin with the letter 'E'. Equates are grouped into related
;       sets. Equates here are defined in the following groupings:
;
;       Hardware-Defined Values
;
;       ECRT...         6845 Cathode Ray Tube (CRT) Controller values
;       EFDC...         NEC 765 Floppy Disk Controller (FDC) values
;       EKEYB...        8042 or "PS/2 Controller" (Keyboard Controller) values
;       EPIC...         8259 Programmable Interrupt Controller (PIC) values
;       EPIT...         8253 Programmable Interval Timer (PIT) values
;       EX86...         Intel x86 CPU architecture values
;
;       Firmware-Defined Values
;
;       EBIOS...        Basic Input/Output System (BIOS) values
;
;       Standards-Based Values
;
;       EASCII...       American Standard Code for Information Interchange (ASCII) values
;
;       Operating System Values
;
;       EBOOT...        Boot sector and loader values
;       ECON...         Console values (dimensions and attributes)
;       EGDT...         Global Descriptor Table (GDT) selector values
;       EKEYF...        Keyboard status flags
;       EKRN...         Kernel values (fixed locations and sizes)
;       ELDT...         Local Descriptor Table (LDT) selector values
;       EMEM...         Memory Management values
;       EMSG...         Message identifers
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Hardware-Defined Values
;
;-----------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------
;
;       6845 Cathode Ray Tube (CRT) Controller                                  ECRT...
;
;       The Motorola 6845 CRT Controller (CRTC) is a programmable controller
;       for CGA, EGA, VGA and compatible video modes.
;
;-----------------------------------------------------------------------------------------------------------------------
ECRTPORTHI              equ     003h                                            ;controller port hi
ECRTPORTLO              equ     0D4h                                            ;controller port lo
ECRTCURLOCHI            equ     00Eh                                            ;cursor loc reg hi
ECRTCURLOCLO            equ     00Fh                                            ;cursor loc reg lo
;-----------------------------------------------------------------------------------------------------------------------
;
;       NEC 765 Floppy Disk Controller (FDC)                                    EFDC...
;
;       The NEC 765 FDC is a programmable controller for floppy disk drives.
;
;-----------------------------------------------------------------------------------------------------------------------
EFDCPORTHI              equ     003h                                            ;controller port hi
EFDCPORTLOOUT           equ     0F2h                                            ;digital output register lo
EFDCPORTLOSTAT          equ     0F4h                                            ;main status register lo
EFDCSTATBUSY            equ     010h                                            ;main status is busy
EFDCMOTOROFF            equ     00Ch                                            ;motor off / enable / DMA
;-----------------------------------------------------------------------------------------------------------------------
;
;       8042 Keyboard Controller                                                EKEYB...
;
;       The 8042 Keyboard Controller (8042) is a programmable controller that accepts input signals from the keyboard
;       device. It also signals a hardware interrupt to the CPU when the low-order bit of I/O port 64h is set to zero.
;
;-----------------------------------------------------------------------------------------------------------------------
EKEYBPORTDATA           equ     060h                                            ;data port
EKEYBPORTSTAT           equ     064h                                            ;status port
EKEYBCMDRESET           equ     0FEh                                            ;reset bit 0 to restart system
EKEYBBITOUT             equ     001h                                            ;output buffer status bit
EKEYBBITIN              equ     002h                                            ;input buffer status bit
EKEYBCMDLAMPS           equ     0EDh                                            ;set/reset lamps command
EKEYBWAITLOOP           equ     010000h                                         ;wait loop
                                                                                ;---------------------------------------
                                                                                ;       Keyboard Scan Codes
                                                                                ;---------------------------------------
EKEYBCTRLDOWN           equ     01Dh                                            ;control key down
EKEYBPAUSEDOWN          equ     01Dh                                            ;pause key down (e1 1d ... )
EKEYBSHIFTLDOWN         equ     02Ah                                            ;left shift key down
EKEYBPRTSCRDOWN         equ     02Ah                                            ;print-screen key down (e0 2a ...)
EKEYBSLASH              equ     035h                                            ;slash
EKEYBSHIFTRDOWN         equ     036h                                            ;right shift key down
EKEYBALTDOWN            equ     038h                                            ;alt key down
EKEYBCAPSDOWN           equ     03Ah                                            ;caps-lock down
EKEYBNUMDOWN            equ     045h                                            ;num-lock down
EKEYBSCROLLDOWN         equ     046h                                            ;scroll-lock down
EKEYBINSERTDOWN         equ     052h                                            ;insert down (e0 52)
EKEYBUP                 equ     080h                                            ;up
EKEYBCTRLUP             equ     09Dh                                            ;control key up
EKEYBSHIFTLUP           equ     0AAh                                            ;left shift key up
EKEYBSLASHUP            equ     0B5h                                            ;slash key up
EKEYBSHIFTRUP           equ     0B6h                                            ;right shift key up
EKEYBPRTSCRUP           equ     0B7h                                            ;print-screen key up (e0 b7 ...)
EKEYBALTUP              equ     0B8h                                            ;alt key up
EKEYBCAPSUP             equ     0BAh                                            ;caps-lock up
EKEYBNUMUP              equ     0C5h                                            ;num-lock up
EKEYBSCROLLUP           equ     0C6h                                            ;scroll-lock up
EKEYBINSERTUP           equ     0D2h                                            ;insert up (e0 d2)
EKEYBCODEEXT0           equ     0E0h                                            ;extended scan code 0
EKEYBCODEEXT1           equ     0E1h                                            ;extended scan code 1
;-----------------------------------------------------------------------------------------------------------------------
;
;       8259 Peripheral Interrupt Controller                                    EPIC...
;
;       The 8259 Peripheral Interrupt Controller (PIC) is a programmable controller that accepts interrupt signals from
;       external devices and signals a hardware interrupt to the CPU.
;
;-----------------------------------------------------------------------------------------------------------------------
EPICPORTPRI             equ     020h                                            ;primary control port 0
EPICPORTPRI1            equ     021h                                            ;primary control port 1
EPICPORTSEC             equ     0A0h                                            ;secondary control port 0
EPICPORTSEC1            equ     0A1h                                            ;secondary control port 1
EPICEOI                 equ     020h                                            ;non-specific EOI code
;-----------------------------------------------------------------------------------------------------------------------
;
;       8253 Programmable Interval Timer                                        EPIT...
;
;       The Intel 8253 Programmable Interval Timer (PIT) is a chip that produces a hardware interrupt (IRQ0)
;       approximately 18.2 times per second.
;
;-----------------------------------------------------------------------------------------------------------------------
EPITDAYTICKS            equ     01800B0h                                        ;ticks per day
;-----------------------------------------------------------------------------------------------------------------------
;
;       x86 CPU Architecture                                                    ;EX86...
;
;-----------------------------------------------------------------------------------------------------------------------
EX86DESCLEN             equ     8                                               ;size of a protected mode descriptor
;-----------------------------------------------------------------------------------------------------------------------
;
;       Motorola MC 146818 Real-Time Clock                                      ERTC...
;
;       The Motorola MC 146818 was the original real-time clock in PCs.
;
;-----------------------------------------------------------------------------------------------------------------------
ERTCREGPORT             equ     070h                                            ;register select port
ERTCDATAPORT            equ     071h                                            ;data port
ERTCSECONDREG           equ     000h                                            ;second
ERTCMINUTEREG           equ     002h                                            ;minute
ERTCHOURREG             equ     004h                                            ;hour
ERTCWEEKDAYREG          equ     006h                                            ;weekday
ERTCDAYREG              equ     007h                                            ;day
ERTCMONTHREG            equ     008h                                            ;month
ERTCYEARREG             equ     009h                                            ;year of the century
ERTCSTATUSREG           equ     00bh                                            ;status
ERTCBASERAMLO           equ     015h                                            ;base RAM low
ERTCBASERAMHI           equ     016h                                            ;base RAM high
ERTCEXTRAMLO            equ     017h                                            ;extended RAM low
ERTCEXTRAMHI            equ     018h                                            ;extended RAM high
ERTCCENTURYREG          equ     032h                                            ;century
ERTCBINARYVALS          equ     00000100b                                       ;values are binary
;-----------------------------------------------------------------------------------------------------------------------
;
;       x86 Descriptor Access Codes                                             EX86ACC...
;
;       The x86 architecture supports the classification of memory areas or segments. Segment attributes are defined by
;       structures known as descriptors. Within a descriptor are access type codes that define the type of the segment.
;
;       0.......        Segment is not present in memory (triggers int 11)
;       1.......        Segment is present in memory
;       .LL.....        Segment is of privilege level LL (0,1,2,3)
;       ...0....        Segment is a system segment
;       ...00010                Local Descriptor Table
;       ...00101                Task Gate
;       ...010B1                Task State Segment (B:0=Available,1=Busy)
;       ...01100                Call Gate (386)
;       ...01110                Interrupt Gate (386)
;       ...01111                Trap Gate (386)
;       ...1...A        Segment is a code or data (A:1=Accesssed)
;       ...10DW.                Data (D:1=Expand Down,W:1=Writable)
;       ...11CR.                Code (C:1=Conforming,R:1=Readable)
;
;-----------------------------------------------------------------------------------------------------------------------
EX86ACCLDT              equ     10000010b                                       ;local descriptor table
EX86ACCTASK             equ     10000101b                                       ;task gate
EX86ACCTSS              equ     10001001b                                       ;task-state segment
EX86ACCGATE             equ     10001100b                                       ;call gate
EX86ACCINT              equ     10001110b                                       ;interrupt gate
EX86ACCTRAP             equ     10001111b                                       ;trap gate
EX86ACCDATA             equ     10010011b                                       ;upward writable data
EX86ACCCODE             equ     10011011b                                       ;non-conforming readable code
;-----------------------------------------------------------------------------------------------------------------------
;
;       Firmware-Defined Values
;
;-----------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------
;
;       BIOS Interrupts and Functions                                           EBIOS...
;
;       Basic Input/Output System (BIOS) functions are grouped and accessed by issuing an interrupt call. Each
;       BIOS interrupt supports several funtions. The function code is typically passed in the AH register.
;
;-----------------------------------------------------------------------------------------------------------------------
EBIOSINTVIDEO           equ     010h                                            ;video services interrupt
EBIOSFNSETVMODE         equ     000h                                            ;video set mode function
EBIOSMODETEXT80         equ     003h                                            ;video mode 80x25 text
EBIOSFNTTYOUTPUT        equ     00Eh                                            ;video TTY output function
EBIOSINTDISKETTE        equ     013h                                            ;diskette services interrupt
EBIOSFNREADSECTOR       equ     002h                                            ;diskette read sector function
EBIOSFNWRITESECTOR      equ     003h                                            ;diskette write sector function
EBIOSINTMISC            equ     015h                                            ;miscellaneous services interrupt
EBIOSFNINITPROTMODE     equ     089h                                            ;initialize protected mode fn
EBIOSINTKEYBOARD        equ     016h                                            ;keyboard services interrupt
EBIOSFNKEYSTATUS        equ     001h                                            ;keyboard status function
;-----------------------------------------------------------------------------------------------------------------------
;
;       Standards-Based Values
;
;-----------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------
;
;       ASCII                                                                   EASCII...
;
;-----------------------------------------------------------------------------------------------------------------------
EASCIIBACKSPACE         equ     008h                                            ;backspace
EASCIILINEFEED          equ     00Ah                                            ;line feed
EASCIIRETURN            equ     00Dh                                            ;carriage return
EASCIIESCAPE            equ     01Bh                                            ;escape
EASCIISPACE             equ     020h                                            ;space
EASCIIPERIOD            equ     02Eh                                            ;period
EASCIIUPPERA            equ     041h                                            ;'A'
EASCIIUPPERZ            equ     05Ah                                            ;'Z'
EASCIILOWERA            equ     061h                                            ;'a'
EASCIILOWERZ            equ     07Ah                                            ;'z'
EASCIITILDE             equ     07Eh                                            ;'~'
EASCIIBORDSGLVERT       equ     0B3h                                            ;vertical single border
EASCIIBORDSGLUPRRGT     equ     0BFh                                            ;upper-right single border
EASCIIBORDSGLLWRLFT     equ     0C0h                                            ;lower-left single border
EASCIIBORDSGLHORZ       equ     0C4h                                            ;horizontal single border
EASCIIBORDSGLLWRRGT     equ     0D9h                                            ;lower-right single border
EASCIIBORDSGLUPRLFT     equ     0DAh                                            ;upper-left single border
EASCIICASE              equ     00100000b                                       ;case bit
EASCIICASEMASK          equ     11011111b                                       ;case mask
;-----------------------------------------------------------------------------------------------------------------------
;
;       PCI                                                                     EPCI...
;
;-----------------------------------------------------------------------------------------------------------------------
EPCIVENDORAPPLE         equ     106Bh                                           ;Apple
EPCIVENDORINTEL         equ     8086h                                           ;Intel
EPCIVENDORORACLE        equ     80EEh                                           ;Oracle
EPCIAPPLEUSB            equ     003Fh                                           ;USB Controller
EPCIINTELPRO1000MT      equ     100Fh                                           ;Pro/1000 MT Ethernet Adapter
EPCIINTELPCIMEM         equ     1237h                                           ;PCI & Memory
EPCIINTELAD1881         equ     2415h                                           ;Aureal AD1881 SOUNDMAX
EPCIINTELPIIX3          equ     7000h                                           ;PIIX3 PCI-to-ISA Bridge (Triton II)
EPCIINTEL82371AB        equ     7111h                                           ;82371AB/EB PCI Bus Master IDE Cntrlr
EPCIINTELPIIX4          equ     7113h                                           ;PIIX4/4E/4M Power Mgmt Cntrlr
EPCIORACLEVBOXGA        equ     0BEEFh                                          ;VirtualBox Graphics Adapter
EPCIORACLEVBOXDEVICE    equ     0CAFEh                                          ;VirtualBox Device
;-----------------------------------------------------------------------------------------------------------------------
;
;       Operating System Values
;
;-----------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------
;       Background Task Identifiers                                             EBG...
;-----------------------------------------------------------------------------------------------------------------------
EBGTIMELEN              equ     9                                               ;length of time string HH:MM:SS\0
;-----------------------------------------------------------------------------------------------------------------------
;
;       Boot Sector and Loader Constants                                        EBOOT...
;
;       Equates in this section support the boot sector and the 16-bit operating system loader, which will be
;       responsible for placing the CPU into protected mode and calling the initial operating system task.
;
;-----------------------------------------------------------------------------------------------------------------------
EBOOTSTACKTOP           equ     0100h                                           ;boot sector stack top relative to DS
EBOOTSECTORBYTES        equ     512                                             ;bytes per sector
EBOOTDIRENTRIES         equ     224                                             ;directory entries
EBOOTDISKSECTORS        equ     2880                                            ;sectors per disk
EBOOTDISKBYTES          equ     (EBOOTSECTORBYTES*EBOOTDISKSECTORS)             ;bytes per disk
EBOOTFATBASE            equ     (EBOOTSTACKTOP+EBOOTSECTORBYTES)                ;offset of FAT I/O buffer rel to DS
EBOOTMAXTRIES           equ     5                                               ;max read retries
;-----------------------------------------------------------------------------------------------------------------------
;       Console Constants                                                       ECON...
;-----------------------------------------------------------------------------------------------------------------------
ECONCOLS                equ     80                                              ;columns per row
ECONROWS                equ     24                                              ;console rows
ECONOIAROW              equ     24                                              ;operator information area row
ECONCOLBYTES            equ     2                                               ;bytes per column
ECONROWBYTES            equ     (ECONCOLS*ECONCOLBYTES)                         ;bytes per row
ECONROWDWORDS           equ     (ECONROWBYTES/4)                                ;double-words per row
ECONCLEARDWORD          equ     007200720h                                      ;attribute and ASCII space
ECONOIADWORD            equ     070207020h                                      ;attribute and ASCII space
;-----------------------------------------------------------------------------------------------------------------------
;       Global Descriptor Table (GDT) Selectors                                 EGDT...
;-----------------------------------------------------------------------------------------------------------------------
EGDTALIAS               equ     008h                                            ;gdt alias selector
EGDTOSDATA              equ     018h                                            ;kernel data selector
EGDTCGA                 equ     020h                                            ;cga video selector
EGDTLOADERCODE          equ     030h                                            ;loader code selector
EGDTOSCODE              equ     048h                                            ;os kernel code selector
EGDTLOADERLDT           equ     050h                                            ;loader local descriptor table selector
EGDTLOADERTSS           equ     058h                                            ;loader task state segment selector
EGDTCONSOLELDT          equ     060h                                            ;console local descriptor table selector
EGDTCONSOLETSS          equ     068h                                            ;console task state segment selector
ESELBACKGROUNDLDT       equ     070h                                            ;background local descr table selector
ESELBACKGROUNDTSS       equ     078h                                            ;background task state segment selector
ESELKEYBOARDMQ          equ     080h                                            ;keyboard focus message queue (IRQ1)
;-----------------------------------------------------------------------------------------------------------------------
;       LDT Selectors                                                           ESEL...
;-----------------------------------------------------------------------------------------------------------------------
ESELMQ                  equ     02Ch                                            ;console task message queue
;-----------------------------------------------------------------------------------------------------------------------
;       Keyboard Flags                                                          EKEYF...
;-----------------------------------------------------------------------------------------------------------------------
EKEYFCTRLLEFT           equ     00000001b                                       ;left control
EKEYFSHIFTLEFT          equ     00000010b                                       ;left shift
EKEYFALTLEFT            equ     00000100b                                       ;left alt
EKEYFCTRLRIGHT          equ     00001000b                                       ;right control
EKEYFSHIFTRIGHT         equ     00010000b                                       ;right shift
EKEYFSHIFT              equ     00010010b                                       ;left or right shift
EKEYFALTRIGHT           equ     00100000b                                       ;right alt
EKEYFLOCKSCROLL         equ     00000001b                                       ;scroll-lock flag
EKEYFLOCKNUM            equ     00000010b                                       ;num-lock flag
EKEYFLOCKCAPS           equ     00000100b                                       ;cap-lock flag
EKEYFTIMEOUT            equ     10000000b                                       ;controller timeout
;-----------------------------------------------------------------------------------------------------------------------
;       Kernel Constants                                                        EKRN...
;-----------------------------------------------------------------------------------------------------------------------
EKRNDATASEG             equ     00000h                                          ;kernel data segment (0000:0800)
EKRNCODEBASE            equ     1000h                                           ;kernel base address (0000:1000)
EKRNCODESEG             equ     (EKRNCODEBASE >> 4)                             ;kernel code segment (0100:0000)
EKRNCODELEN             equ     7000h                                           ;kernel code size (1000h to 8000h)
EKRNCODESRCADR          equ     500h                                            ;kernel code offset to loader DS:
EKRNHEAPSIZE            equ     80000000h                                       ;kernel heap size
EKRNHEAPBASE            equ     10000h                                          ;kernel heap base
;-----------------------------------------------------------------------------------------------------------------------
;       Local Descriptor Table (LDT) Selectors                                  ELDT...
;-----------------------------------------------------------------------------------------------------------------------
ELDTMQ                  equ     02Ch                                            ;console task message queue
;-----------------------------------------------------------------------------------------------------------------------
;       Hardware Flags
;-----------------------------------------------------------------------------------------------------------------------
EHWETHERNET             equ     80h                                             ;ethernet adapter found
;-----------------------------------------------------------------------------------------------------------------------
;       Memory Management Constants                                             EMEM...
;-----------------------------------------------------------------------------------------------------------------------
EMEMMINSIZE             equ     256                                             ;minimum heap block size (incl. hdr)
EMEMFREECODE            equ     "FREE"                                          ;free memory signature
EMEMUSERCODE            equ     "USER"                                          ;user memory signature
EMEMWIPEBYTE            equ     000h                                            ;byte value to wipe storage
;-----------------------------------------------------------------------------------------------------------------------
;       Message Identifiers                                                     EMSG...
;-----------------------------------------------------------------------------------------------------------------------
EMSGKEYDOWN             equ     041000000h                                      ;key-down
EMSGKEYUP               equ     041010000h                                      ;key-up
EMSGKEYCHAR             equ     041020000h                                      ;character
;=======================================================================================================================
;
;       Structures
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       DATETIME
;
;       The DATETIME structure stores date and time values from the real-time clock.
;
;-----------------------------------------------------------------------------------------------------------------------
struc                   DATETIME
.second                 resb    1                                               ;seconds
.minute                 resb    1                                               ;minutes
.hour                   resb    1                                               ;hours
.weekday                resb    1                                               ;day of week
.day                    resb    1                                               ;day of month
.month                  resb    1                                               ;month of year
.year                   resb    1                                               ;year of century
.century                resb    1                                               ;century
EDATETIMELEN            equ     ($-.second)
endstruc
;-----------------------------------------------------------------------------------------------------------------------
;
;       MEMBLOCK
;
;       The MEMBLOCK structure defines a memory block.
;
;-----------------------------------------------------------------------------------------------------------------------
struc                   MEMBLOCK
.signature              resd    1                                               ;starting signature
.bytes                  resd    1                                               ;block size in bytes
.owner                  resd    1                                               ;owning task
.reserved               resd    1                                               ;reserved
.nextcontig             resd    1                                               ;next contiguous block
.previouscontig         resd    1                                               ;previous contiguous block
.nextblock              resd    1                                               ;next free/task block
.previousblock          resd    1                                               ;previous free/task block
EMEMBLOCKLEN            equ     ($-.signature)
endstruc
;-----------------------------------------------------------------------------------------------------------------------
;
;       MEMROOT
;
;       The MEMROOT structure defines starting and ending addresses of memory block chains.
;
;-----------------------------------------------------------------------------------------------------------------------
struc                   MEMROOT
.firstcontig            resd    1                                               ;first contiguous block
.lastcontig             resd    1                                               ;last contiguous block
.firstfree              resd    1                                               ;first free block
.lastfree               resd    1                                               ;last free block
.firsttask              resd    1                                               ;first task block
.lasttask               resd    1                                               ;last task block
EMEMROOTLEN             equ     ($-.firstcontig)
endstruc
;-----------------------------------------------------------------------------------------------------------------------
;
;       MQUEUE
;
;       The MQUEUE structure maps memory used for a message queue.
;
;-----------------------------------------------------------------------------------------------------------------------
struc                   MQUEUE
MQHead                  resd    1                                               ;000 head ptr
MQTail                  resd    1                                               ;004 tail ptr
MQData                  resd    254                                             ;message queue
endstruc
;-----------------------------------------------------------------------------------------------------------------------
;
;       OSDATA
;
;       The OSDATA structure maps low-memory addresses used by the BIOS and the OS. Areas that may be in use by DOS or
;       other host operating systems that may be running when this OS is launched are avoided.
;
;-----------------------------------------------------------------------------------------------------------------------
struc                   OSDATA
                        resb    0400h                                           ;000 real mode interrupt vectors
                        resw    1                                               ;400 COM1 port address
                        resw    1                                               ;402 COM2 port address
                        resw    1                                               ;404 COM3 port address
                        resw    1                                               ;406 COM4 port address
                        resw    1                                               ;408 LPT1 port address
                        resw    1                                               ;40a LPT2 port address
                        resw    1                                               ;40c LPT3 port address
                        resw    1                                               ;40e LPT4 port address
                        resb    2                                               ;410 equipment list flags
                        resb    1                                               ;412 errors in PCjr infrared keybd link
wwROMMemSize            resw    1                                               ;413 memory size (kb) INT 12h
                        resb    1                                               ;415 mfr error test scratchpad
                        resb    1                                               ;416 PS/2 BIOS control flags
                        resb    1                                               ;417 keyboard flag byte 0
                        resb    1                                               ;418 keyboard flag byte 1
                        resb    1                                               ;419 alternate keypad entry
                        resw    1                                               ;41a keyboard buffer head offset
                        resw    1                                               ;41c keyboard buffer tail offset
                        resb    32                                              ;41e keyboard buffer
wbFDCStatus             resb    1                                               ;43e drive recalibration status
wbFDCControl            resb    1                                               ;43f FDC motor status/control byte
wbFDCMotor              resb    1                                               ;440 FDC motor timeout byte
                        resb    1                                               ;441 status of last diskette operation
                        resb    7                                               ;442 NEC diskette controller status
                        resb    1                                               ;449 current video mode
                        resw    1                                               ;44a screen columns
                        resw    1                                               ;44c video regen buffer size
                        resw    1                                               ;44e current video page offset
                        resw    8                                               ;450 cursor postions of pages 1-8
                        resb    1                                               ;460 cursor ending scanline
                        resb    1                                               ;461 cursor start scanline
                        resb    1                                               ;462 active display page number
                        resw    1                                               ;463 CRTC base port address
                        resb    1                                               ;465 CRT mode control register value
                        resb    1                                               ;466 CGA current color palette mask
                        resw    1                                               ;467 CS:IP for 286 return from PROT MODE
                        resb    3                                               ;469 vague
wdClockTicks            resd    1                                               ;46c clock ticks
wbClockDays             resb    1                                               ;470 clock days
                        resb    1                                               ;471 bios break flag
                        resw    1                                               ;472 soft reset
                        resb    1                                               ;474 last hard disk operation status
                        resb    1                                               ;475 hard disks attached
                        resb    1                                               ;476 XT fised disk drive control byte
                        resb    1                                               ;477 port offset to current fixed disk adapter
                        resb    4                                               ;478 LPT timeout values
                        resb    4                                               ;47c COM timeout values
                        resw    1                                               ;480 keyboard buffer start offset
                        resw    1                                               ;482 keyboard buffer end offset
                        resb    1                                               ;484 Rows on screen less 1 (EGA+)
                        resb    1                                               ;485 point height of character matrix (EGA+)
                        resb    1                                               ;486 PC Jr initial keybd delay
                        resb    1                                               ;487 EGA+ video mode ops
                        resb    1                                               ;488 EGA feature bit switches
                        resb    1                                               ;489 VGA video display data area
                        resb    1                                               ;48a EGA+ display combination code
                        resb    1                                               ;48b last diskette data rate selected
                        resb    1                                               ;48c hard disk status from controller
                        resb    1                                               ;48d hard disk error from controller
                        resb    1                                               ;48e hard disk interrupt control flag
                        resb    1                                               ;48f combination hard/floppy disk card
                        resb    4                                               ;490 drive 0,1,2,3 media state
                        resb    1                                               ;494 track currently seeked to on drive 0
                        resb    1                                               ;495 track currently seeked to on drive 1
                        resb    1                                               ;496 keyboard mode/type
                        resb    1                                               ;497 keyboard LED flags
                        resd    1                                               ;498 pointer to user wait complete flag
                        resd    1                                               ;49c user wait time-out value in microseconds
                        resb    1                                               ;4a0 RTC wait function flag
                        resb    1                                               ;4a1 LANA DMA channel flags
                        resb    2                                               ;4a2 status of LANA 0,1
                        resd    1                                               ;4a4 saved hard disk interrupt vector
                        resd    1                                               ;4a8 BIOS video save/override pointer table addr
                        resb    8                                               ;4ac reserved
                        resb    1                                               ;4b4 keyboard NMI control flags
                        resd    1                                               ;4b5 keyboard break pending flags
                        resb    1                                               ;4b9 Port 60 single byte queue
                        resb    1                                               ;4ba scan code of last key
                        resb    1                                               ;4bb NMI buffer head pointer
                        resb    1                                               ;4bc NMI buffer tail pointer
                        resb    16                                              ;4bd NMI scan code buffer
                        resb    1                                               ;4cd unknown
                        resw    1                                               ;4de day counter
                        resb    32                                              ;4d0 unknown
                        resb    16                                              ;4f0 intra-app comm area
                        resb    1                                               ;500 print-screen status byte
                        resb    3                                               ;501 used by BASIC
                        resb    1                                               ;504 DOS single diskette mode
                        resb    10                                              ;505 POST work area
                        resb    1                                               ;50f BASIC shell flag
                        resw    1                                               ;510 BASIC default DS (DEF SEG)
                        resd    1                                               ;512 BASIC INT 1C interrupt handler
                        resd    1                                               ;516 BASIC INT 23 interrupt handler
                        resd    1                                               ;51a BASIC INT 24 interrupt handler
                        resw    1                                               ;51e unknown
                        resw    1                                               ;520 DOS dynamic storage
                        resb    14                                              ;522 DOS diskette initialization table (INT 1e)
                        resb    4                                               ;530 MODE command
                        resb    460                                             ;534 unused
                        resb    256                                             ;700 i/o drivers from io.sys/ibmbio.com
;-----------------------------------------------------------------------------------------------------------------------
;
;       Kernel Variables                                                        @disk: N/A      @mem: 000800
;
;       Kernel variables may be accessed by interrupts or by the initial task (Console).
;
;-----------------------------------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------
;
;       Kernel Data
;
;       These variables are not task-specific. They are initialized by the OS loader before the system is placed into
;       protected mode. This is necessary because as soon as the system enters protected mode, the timer interrupt
;       (IRQ0) will begin to reference the task selectors queue to implement task switching.
;
;-----------------------------------------------------------------------------------------------------------------------
                        alignb  4
EKERNELDATA             equ     ($)
wwTaskQueue             resw    256                                             ;task selector queue
wdFarJumpEIP            resd    1                                               ;destination EIP of next task (ignored)
wwFarJumpSelector       resw    1                                               ;destination task gate
wbTaskIndex             resb    1                                               ;task selector index
wbInCriticalSection     resb    1                                               ;task in critical section
EKERNELDATALEN          equ     ($-EKERNELDATA)
;-----------------------------------------------------------------------------------------------------------------------
;
;       Console Task Variables
;
;       These variables are exclusve to the console task. These variables are initialized by the console task when
;       the console task starts.
;
;-----------------------------------------------------------------------------------------------------------------------
                        alignb  4
ECONDATA                equ     ($)
wdConsoleMemBase        resd    1                                               ;console memory address
wdConsoleHeapSize       resd    1                                               ;kernel heap size
wdBaseMemSize           resd    1                                               ;base memory size (int 12h)
wdExtendedMemSize       resd    1                                               ;extended memory size (int 12h)
wdROMMemSize            resd    1                                               ;ROM memory size
wdConsolePCISelector    resd    1                                               ;PCI selector (bbbbbbbb dddddfff)
wdConsolePCIData        equ     $                                               ;PCI register data value
wwConsolePCIVendor      resw    1                                               ;PCI data vendor
wwConsolePCIChip        resw    1                                               ;PCI data chip
wdConsolePCIVendorStr   resd    1                                               ;PCI vendor name string addr
wdConsolePCIChipStr     resd    1                                               ;PCI device name string addr
wdConsoleEthernetDevice resd    1                                               ;PCI ethernet adapter selector
wdConsoleEthernetMem    resd    1                                               ;PCI ethernet memory mapped i/o address
wdConsoleEthernetPort   resd    1                                               ;PCI ethernet i/o port
wdConsoleEthernetCtrl   resd    1                                               ;PCI ethernet control register value
wbConsoleColumn         resb    1                                               ;console column
wbConsoleRow            resb    1                                               ;console row
wbConsoleShift          resb    1                                               ;console shift flags
wbConsoleLock           resb    1                                               ;console lock flags
wbConsoleStatus         resb    1                                               ;controller status
wbConsoleScan0          resb    1                                               ;scan code
wbConsoleScan1          resb    1                                               ;scan code
wbConsoleScan2          resb    1                                               ;scan code
wbConsoleScan3          resb    1                                               ;scan code
wbConsoleScan4          resb    1                                               ;scan code
wbConsoleScan5          resb    1                                               ;scan code
wbConsoleChar           resb    1                                               ;ASCII code
wbConsolePCIBus         resb    1                                               ;PCI bus
wbConsolePCIDevice      resb    1                                               ;PCI device
wbConsolePCIFunction    resb    1                                               ;PCI function
wbConsoleHWFlags        resb    1                                               ;Hardware Flags
wzConsoleInBuffer       resb    80                                              ;command input buffer
wzConsoleToken          resb    80                                              ;token buffer
wzConsoleOutBuffer      resb    80                                              ;response output buffer
wzBaseMemSize           resb    11                                              ;CMOS base memory bytes     zz,zzz,zz9\0
wzROMMemSize            resb    11                                              ;ROM base memory bytes      zz,zzz,zz9\0
wzExtendedMemSize       resb    11                                              ;CMOS extended memory bytes zz,zzz,zz9\0
wsConsoleMemRoot        resb    EMEMROOTLEN                                     ;kernel base memory map
wsConsoleDateTime       resb    EDATETIMELEN                                    ;date-time buffer
ECONDATALEN             equ     ($-ECONDATA)                                    ;size of console data area
;-----------------------------------------------------------------------------------------------------------------------
;
;       Background Task Variables
;
;       These variables are exclusve to the background task. These variables are initialized by the background task when
;       the task starts.
;
;-----------------------------------------------------------------------------------------------------------------------
                        alignb  4
EBGDATA                 equ     ($)
wsBgDateTime            resb    EDATETIMELEN                                    ;date-time buffer
wzBgTime                resb    EBGTIMELEN                                      ;time string buffer
wzBgTimeCmpr            resb    EBGTIMELEN                                      ;time string comparison buffer
EBGDATALEN              equ     ($-EBGDATA)
;-----------------------------------------------------------------------------------------------------------------------
;
;       End of OS Variables
;
;-----------------------------------------------------------------------------------------------------------------------
endstruc
;-----------------------------------------------------------------------------------------------------------------------
;
;       Macros
;
;       These macros are used to assist in defining descriptor tables and interrupt table offsets.
;
;-----------------------------------------------------------------------------------------------------------------------
%macro                  mint    1
_%1                     equ     ($-$$) / EX86DESCLEN
                        dq      ((?%1 >> 16) << 32) | (EX86ACCINT << 40) | ((EGDTOSCODE & 0FFFFh) << 16) | (?%1 & 0FFFFh)
%endmacro
%macro                  mtrap   1
_%1                     equ     ($-$$) / EX86DESCLEN
                        dq      ((?%1 >> 16) << 32) | (EX86ACCTRAP << 40) | ((EGDTOSCODE & 0FFFFh) << 16) | (?%1 & 0FFFFh)
%endmacro
%macro                  menter  1
?%1                     equ     ($-$$)
%endmacro
%macro                  tsvce   1
e%1                     equ     ($-tsvc)/4
                        dd      %1
%endmacro
%ifdef BUILDBOOT
;=======================================================================================================================
;
;       Boot Sector                                                             @disk: 000000   @mem: 007c00
;
;       The first sector of the disk is the boot sector. The BIOS will load the boot sector into memory and pass
;       control to the code at the start of the sector. The boot sector code is responsible for loading the operating
;       system into memory. The boot sector contains a disk parameter table describing the geometry and allocation
;       of the disk. Following the disk parameter table is code to load the operating system kernel into memory.
;
;       The "cpu" directive limits emitted code to those instructions supported by the most primitive processor
;       we expect to ever execute our code. The "vstart" parameter indicates addressability of symbols so as to
;       emulate the DOS .COM program model. Although the BIOS is expected to load the boot sector at address 7c00,
;       we do not make that assumption. The CPU starts in 16-bit addressing mode. A three-byte jump instruction is
;       immediately followed by a disk parameter table.
;
;=======================================================================================================================
                        cpu     8086                                            ;assume minimal CPU
section                 boot    vstart=0100h                                    ;emulate .COM (CS,DS,ES=PSP) addressing
                        bits    16                                              ;16-bit code at power-up
%ifdef BUILDPREP
Boot                    jmp     word Prep                                       ;jump to preparation code
%else
Boot                    jmp     word Boot.10                                    ;jump over parameter table
%endif
;-----------------------------------------------------------------------------------------------------------------------
;
;       Disk Parameter Table
;
;       The disk parameter table informs the BIOS of the floppy disk architecture. Here, we use parameters for the
;       3.5" 1.44MB floppy disk since this format is widely supported by virtual machine hypervisors.
;
;-----------------------------------------------------------------------------------------------------------------------
                        db      "CustomOS"                                      ;eight-byte label
cwSectorBytes           dw      EBOOTSECTORBYTES                                ;bytes per sector
cbClusterSectors        db      1                                               ;sectors per cluster
cwReservedSectors       dw      1                                               ;reserved sectors
cbFatCount              db      2                                               ;file allocation table copies
cwDirEntries            dw      EBOOTDIRENTRIES                                 ;max directory entries
cwDiskSectors           dw      EBOOTDISKSECTORS                                ;sectors per disk
cbDiskType              db      0F0h                                            ;1.44MB
cwFatSectors            dw      9                                               ;sectors per FAT copy
cbTrackSectors          equ     $                                               ;sectors per track (as byte)
cwTrackSectors          dw      18                                              ;sectors per track (as word)
cwDiskSides             dw      2                                               ;sides per disk
cwSpecialSectors        dw      0                                               ;special sectors
;
;       BIOS typically loads the boot sector at absolute address 7c00 and sets the stack pointer at 512 bytes past the
;       end of the boot sector. But, since BIOS code varies, we don't make any assumptions as to where our boot sector
;       is loaded. For example, the initial CS:IP could be 0:7c00, 700:c00, 7c0:0, etc. So, to avoid assumptions, we
;       first normalize CS:IP to get the absolute segment address in BX. The comments below show the effect of this code
;       given several possible starting values for CS:IP.
;
                                                                                ;CS:IP   0:7c00 700:c00 7c0:0
Boot.10                 call    word .20                                        ;[ESP] =   7c21     c21    21
.@20                    equ     $-$$                                            ;.@20 = 021h
.20                     pop     ax                                              ;AX =      7c21     c21    21
                        sub     ax,.@20                                         ;AX =      7c00     c00     0
                        mov     cl,4                                            ;shift count
                        shr     ax,cl                                           ;AX =       7c0      c0     0
                        mov     bx,cs                                           ;BX =         0     700   7c0
                        add     bx,ax                                           ;BX =       7c0     7c0   7c0
;
;       Now, since we are assembling our boot code to emulate the addressing of a .COM file, we want the DS and ES
;       registers to be set to where a Program Segment Prefix (PSP) would be, exactly 100h (256) bytes prior to
;       the start of our code. This will correspond to our assembled data address offsets. Note that we instructed
;       the assembler to produce addresses for our symbols that are offset from our code by 100h. See the "vstart"
;       parameter for the "section" directive above. We also set SS to the PSP and SP to the address of our i/o
;       buffer. This leaves 256 bytes of usable stack from 7b0:0 to 7b0:100.
;
                        sub     bx,16                                           ;BX = 07b0
                        mov     ds,bx                                           ;DS = 07b0 = psp
                        mov     es,bx                                           ;ES = 07b0 = psp
                        mov     ss,bx                                           ;SS = 07b0 = psp (ints disabled)
                        mov     sp,EBOOTSTACKTOP                                ;SP = 0100       (ints enabled)
;
;       Our boot addressability is now set up according to the following diagram.
;
;       DS,ES,SS -----> 007b00  +-----------------------------------------------+ DS:0000
;                               |  Boot Stack & Boot PSP (Unused)               |
;                               |  256 = 100h bytes                             |
;       SS:SP --------> 007c00  +-----------------------------------------------+ DS:0100  07b0:0100
;                               |  Boot Sector (vstart=0100h)                   |
;                               |  1 sector = 512 = 200h bytes                  |
;                       007e00  +-----------------------------------------------+ DS:0300
;                               |  File Allocation Table (FAT) I/O Buffer       |
;                               |  9x512-byte sectors = 4,608 = 1200h bytes     |
;                       009000  +-----------------------------------------------+ DS:1500  08f0:0100
;                               |  Directory Sector Buffer & Kernel Load Area   |
;                               |  2 sectors = 1024 = 400h bytes
;                       009400  +-----------------------------------------------+ DS:1900
;
;       On entry, DL indicates the drive being booted from.
;
                        mov     [wbDrive],dl                                    ;[wbDrive] = drive being booted from
;
;       Compute directory i/o buffer address.
;
                        mov     ax,[cwFatSectors]                               ;AX = 0009 = FAT sectors
                        mul     word [cwSectorBytes]                            ;DX:AX = 0000:1200 = FAT bytes
                        add     ax,EBOOTFATBASE                                 ;AX = 1500 = end of FAT buffer
                        mov     [wwDirBuffer],ax                                ;[wwDirBuffer] = 1500
;
;       Compute segment where os.com will be loaded.
;
                        shr     ax,cl                                           ;AX = 0150
                        add     ax,bx                                           ;AX = 0150 + 07b0 = 0900
                        sub     ax,16                                           ;AX = 08f0
                        mov     [wwLoadSegment],ax                              ;[wwLoadSegment] = 08f0
;
;       Set the video mode to 80 column, 25 row, text.
;
                        mov     ax,EBIOSFNSETVMODE<<8|EBIOSMODETEXT80           ;set mode function, 80x25 text mode
                        int     EBIOSINTVIDEO                                   ;call BIOS display interrupt
;
;       Write a message to the console so we know we have our addressability established.
;
                        mov     si,czLoadMsg                                    ;loading message
                        call    BootPrint                                       ;display loader message
;
;       Initialize the number of directory sectors to search.
;
                        mov     ax,[cwDirEntries]                               ;AX = 224 = max dir entries
                        mov     [wwEntriesLeft],ax                              ;[wwEntriesLeft] = 224
;
;       Compute number of directory sectors and initialize overhead count.
;
                        mov     cx,ax                                           ;CX = 00e0 = 224 entries
                        mul     word [cwEntryLen]                               ;DX:AX = 224 * 32 = 7168
                        div     word [cwSectorBytes]                            ;AX = 7168 / 512 = 14 = dir sectors
                        mov     [wwOverhead],ax                                 ;[wwOverhead] = 000e
;
;       Compute directory entries per sector.
;
                        xchg    ax,cx                                           ;DX:AX = 0:00e0, CX = 0000e
                        div     cx                                              ;AX = 0010 = entries per dir sector
                        mov     [wwSectorEntries],ax                            ;[wwSectorEntries] = 0010
;
;       Compute first logical directory sector and update overhead count.
;
                        mov     ax,[cwFatSectors]                               ;AX = 0009 = FAT sectors per copy
                        mul     byte [cbFatCount]                               ;AX = 0012 = FAT sectors
                        add     ax,[cwReservedSectors]                          ;AX = 0013 = FAT plus reserved
                        add     ax,[cwSpecialSectors]                           ;AX = 0013 = FAT + reserved + special
                        mov     [wwLogicalSector],ax                            ;[wwLogicalSector] = 0013
                        add     [wwOverhead],ax                                 ;[wwOverhead] = 0021 = res+spec+FAT+dir
;
;       Read directory sector.
;
.30                     mov     al,1                                            ;sector count
                        mov     [wbReadCount],al                                ;[wbReadCount] = 01
                        mov     bx,[wwDirBuffer]                                ;BX = 1500
                        call    ReadSector                                      ;read sector into es:bx
;
;       Setup variables to search this directory sector.
;
                        mov     ax,[wwEntriesLeft]                              ;directory entries to search
                        cmp     ax,[wwSectorEntries]                            ;need to search more sectors?
                        jna     .40                                             ;no, continue
                        mov     ax,[wwSectorEntries]                            ;yes, limit search to sector
.40                     sub     [wwEntriesLeft],ax                              ;update entries left to searh
                        mov     si,cbKernelProgram                              ;program name
                        mov     di,[wwDirBuffer]                                ;DI = 1500
;
;       Loop through directory sectors searching for kernel program.
;
.50                     push    si                                              ;save kernel name address
                        push    di                                              ;save dir i/o buffer address
                        mov     cx,11                                           ;length of 8+3 name
                        cld                                                     ;forward strings
                        repe    cmpsb                                           ;compare entry name
                        pop     di                                              ;restore dir i/o buffer address
                        pop     si                                              ;restore kernel name address
                        je      .60                                             ;exit loop if found
                        add     di,[cwEntryLen]                                 ;point to next dir entry
                        dec     ax                                              ;decrement remaining entries
                        jnz     .50                                             ;next entry
;
;       Repeat search if we are not at the end of the directory.
;
                        inc     word [wwLogicalSector]                          ;increment logical sector
                        cmp     word [wwEntriesLeft],0                          ;done with directory?
                        jne     .30                                             ;no, get next sector
                        mov     si,czNoKernel                                   ;missing kernel message
                        jmp     BootExit                                        ;display message and exit
;
;       If we find the kernel program in the directory, read the FAT.
;
.60                     mov     ax,[cwReservedSectors]                          ;AX = 0001
                        mov     [wwLogicalSector],ax                            ;start past boot sector
                        mov     ax,[cwFatSectors]                               ;AX = 0009
                        mov     [wbReadCount],al                                ;[wbReadCount] = 09
                        mov     bx,EBOOTFATBASE                                 ;BX = 0300
                        call    ReadSector                                      ;read FAT into buffer
;
;       Get the starting cluster of the kernel program and target address.
;
                        mov     ax,[di+26]                                      ;AX = starting cluster of file
                        les     bx,[wwLoadOffset]                               ;ES:BX = kernel load add (08f0:0100)
;
;       Read each program cluster into RAM.
;
.70                     push    ax                                              ;save cluster nbr
                        sub     ax,2                                            ;AX = cluster nbr base 0
                        mov     cl,[cbClusterSectors]                           ;CL = sectors per cluster
                        mov     [wbReadCount],cl                                ;save sectors to read
                        xor     ch,ch                                           ;CX = sectors per cluster
                        mul     cx                                              ;DX:AX = logical cluster sector
                        add     ax,[wwOverhead]                                 ;AX = kernel sector nbr
                        mov     [wwLogicalSector],ax                            ;save logical sector nbr
                        call    ReadSector                                      ;read sectors into ES:BX
;
;       Update buffer pointer for next cluster.
;
                        mov     al,[cbClusterSectors]                           ;AL = sectors per cluster
                        xor     ah,ah                                           ;AX = sectors per cluster
                        mul     word [cwSectorBytes]                            ;DX:AX = cluster bytes
                        add     bx,ax                                           ;BX = next cluster target address
                        pop     ax                                              ;AX = restore cluster nbr
;
;       Compute next cluster number.
;
                        mov     cx,ax                                           ;CX = cluster nbr
                        mov     di,ax                                           ;DI = cluster nbr
                        shr     ax,1                                            ;AX = cluster/2
                        mov     dx,ax                                           ;DX = cluster/2
                        add     ax,dx                                           ;AX = 2*(cluster/2)
                        add     ax,dx                                           ;AX = 3*(cluster/2)
                        and     di,1                                            ;get low bit
                        add     di,ax                                           ;add one if cluster is odd
                        add     di,EBOOTFATBASE                                 ;add FAT buffer address
                        mov     ax,[di]                                         ;get cluster bytes
;
;       Adjust cluster nbr by 4 bits if cluster is odd; test for end of chain.
;
                        test    cl,1                                            ;is cluster odd?
                        jz      .80                                             ;no, skip ahead
                        mov     cl,4                                            ;shift count
                        shr     ax,cl                                           ;shift nybble low
.80                     and     ax,0FFFh                                        ;mask for 24 bits; next cluster nbr
                        cmp     ax,0FFFh                                        ;end of chain?
                        jne     .70                                             ;no, continue
;
;       Transfer control to the operating system program.
;
                        db      0EAh                                            ;jmp seg:offset
wwLoadOffset            dw      0100h                                           ;kernel entry offset
wwLoadSegment           dw      08F0h                                           ;kernel entry segment (computed)
;
;       Read [wbReadCount] disk sectors from [wwLogicalSector] into ES:BX.
;
ReadSector              mov     ax,[cwTrackSectors]                             ;AX = sectors per track
                        mul     word [cwDiskSides]                              ;DX:AX = sectors per cylinder
                        mov     cx,ax                                           ;CX = sectors per cylinder
                        mov     ax,[wwLogicalSector]                            ;DX:AX = logical sector
                        div     cx                                              ;AX = cylinder; DX = cyl sector
                        mov     [wbTrack],al                                    ;[wbTrack] = cylinder
                        mov     ax,dx                                           ;AX = cyl sector
                        div     byte [cbTrackSectors]                           ;AH = sector, AL = head
                        inc     ah                                              ;AH = sector (1,2,3,...)
                        mov     [wbHead],ax                                     ;[wbHead]= head, [wwSectorTrack]= sector
;
;       Try maxtries times to read sector.
;
                        mov     cx,EBOOTMAXTRIES                                ;CX = 0005
.10                     push    bx                                              ;save buffer address
                        push    cx                                              ;save retry count
                        mov     dx,[wwDriveHead]                                ;DH = head, DL = drive
                        mov     cx,[wwSectorTrack]                              ;CH = track, CL = sector
                        mov     ax,[wwReadCountCommand]                         ;AH = fn., AL = sector count
                        int     EBIOSINTDISKETTE                                ;read sector
                        pop     cx                                              ;restore retry count
                        pop     bx                                              ;restore buffer address
                        jnc     BootReturn                                      ;skip ahead if done
                        loop    .10                                             ;retry
;
;       Handle disk error: convert to ASCII and store in error string.
;
                        mov     al,ah                                           ;AL = bios error code
                        xor     ah,ah                                           ;AX = bios error code
                        mov     dl,16                                           ;divisor for base 16
                        div     dl                                              ;AL = hi order, AH = lo order
                        or      ax,03030h                                       ;apply ASCII zone bits
                        cmp     ah,03Ah                                         ;range test ASCII numeral
                        jb      .20                                             ;continue if numeral
                        add     ah,7                                            ;adjust for ASCII 'A'-'F'
.20                     cmp     al,03Ah                                         ;range test ASCII numeral
                        jb      .30                                             ;continue if numeral
                        add     ah,7                                            ;adjust for ASCII 'A'-'F'
.30                     mov     [wzErrorCode],ax                                ;store ASCII error code
                        mov     si,czErrorMsg                                   ;error message address
BootExit                call    BootPrint                                       ;display messge to console
;
;       Wait for a key press.
;
.10                     mov     ah,EBIOSFNKEYSTATUS                             ;BIOS keyboard status function
                        int     EBIOSINTKEYBOARD                                ;get keyboard status
                        jnz     .20                                             ;continue if key pressed
                        sti                                                     ;enable maskable interrupts
                        hlt                                                     ;wait for interrupt
                        jmp     .10                                             ;repeat
;
;       Reset the system.
;
.20                     mov     al,EKEYBCMDRESET                                ;8042 pulse output port pin
                        out     EKEYBPORTSTAT,al                                ;drive B0 low to restart
.30                     sti                                                     ;enable maskable interrupts
                        hlt                                                     ;stop until reset, int, nmi
                        jmp     .30                                             ;loop until restart kicks in
;
;       Display text message.
;
BootPrint               cld                                                     ;forward strings
.10                     lodsb                                                   ;load next byte at DS:SI in AL
                        test    al,al                                           ;end of string?
                        jz      BootReturn                                      ;... yes, exit our loop
                        mov     ah,EBIOSFNTTYOUTPUT                             ;BIOS teletype function
                        int     EBIOSINTVIDEO                                   ;call BIOS display interrupt
                        jmp     .10                                             ;repeat until done
BootReturn              ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Constants
;
;-----------------------------------------------------------------------------------------------------------------------
                        align   2
cwEntryLen              dw      32                                              ;length of directory entry
cbKernelProgram         db      "OS      COM"                                   ;kernel program name
czLoadMsg               db      "Loading OS",13,10,0                            ;loading message
czErrorMsg              db      "Disk error "                                   ;error message
wzErrorCode             db      020h,020h,0                                     ;error code and null terminator
czNoKernel              db      "OS missing",0                                  ;missing kernel message
;-----------------------------------------------------------------------------------------------------------------------
;
;       Work Areas
;
;-----------------------------------------------------------------------------------------------------------------------
                        align   2
wwDirBuffer             dw      0                                               ;directory i/o buffer address
wwEntriesLeft           dw      0                                               ;directory entries to search
wwOverhead              dw      0                                               ;overhead sectors
wwSectorEntries         dw      0                                               ;directory entries per sector
wwLogicalSector         dw      0                                               ;current logical sector
wwReadCountCommand      equ     $                                               ;read count and command
wbReadCount             db      0                                               ;sectors to read
cbReadCommand           db      EBIOSFNREADSECTOR                               ;BIOS read disk fn code
wwDriveHead             equ     $                                               ;drive, head (word)
wbDrive                 db      0                                               ;drive
wbHead                  db      0                                               ;head
wwSectorTrack           equ     $                                               ;sector, track (word)
                        db      0                                               ;sector
wbTrack                 db      0                                               ;track
                        times   510-($-$$) db 0h                                ;zero fill to end of sector
                        db      055h,0AAh                                       ;end of sector signature
%endif
%ifdef BUILDPREP
;=======================================================================================================================
;
;       Diskette Preparation Code
;
;       This routine writes the OS boot sector code to a formatted floppy diskette. The diskette parameter table,
;       which is located in the first 30 bytes of the boot sector is first read from the diskette and overlayed onto
;       the OS bootstrap code so that the diskette format parameters are preserved.
;
;=======================================================================================================================
;
;       Query the user to insert a flopppy diskette and press enter or cancel.
;
Prep                    mov     si,czPrepMsg10                                  ;starting message address
                        call    BootPrint                                       ;display message
;
;       Exit if the Escape key is pressed or loop until Enter is pressed.
;
.10                     mov     ah,EBIOSFNKEYSTATUS                             ;BIOS keyboard status function
                        int     EBIOSINTKEYBOARD                                ;get keyboard status
                        jnz     .20                                             ;continue if key pressed
                        sti                                                     ;enable interrupts
                        hlt                                                     ;wait for interrupt
                        jmp     .10                                             ;repeat
.20                     cmp     al,EASCIIRETURN                                 ;Enter key pressed?
                        je      .30                                             ;yes, branch
                        cmp     al,EASCIIESCAPE                                 ;Escape key pressed?
                        jne     .10                                             ;no, repeat
                        jmp     .120                                            ;yes, exit program
;
;       Display writing-sector message and patch the JMP instruction.
;
.30                     mov     si,czPrepMsg12                                  ;writing-sector message address
                        call    BootPrint                                       ;display message
                        mov     bx,Boot+1                                       ;address of JMP instruction operand
                        mov     ax,01Bh                                         ;address past disk parameter table
                        mov     [bx],ax                                         ;update the JMP instruction
;
;       Try to read the boot sector.
;
                        mov     cx,EBOOTMAXTRIES                                ;try up to five times
.40                     push    cx                                              ;save remaining tries
                        mov     bx,wcPrepInBuf                                  ;input buffer address
                        mov     dx,0                                            ;head zero, drive zero
                        mov     cx,1                                            ;track zero, sector one
                        mov     al,1                                            ;one sector
                        mov     ah,EBIOSFNREADSECTOR                            ;read function
                        int     EBIOSINTDISKETTE                                ;attempt the read
                        pop     cx                                              ;restore remaining retries
                        jnc     .50                                             ;skip ahead if successful
                        loop    .40                                             ;try again
                        mov     si,czPrepMsg20                                  ;read-error message address
                        jmp     .70                                             ;branch to error routine
;
;       Copy diskette parms from input buffer to output buffer.
;
.50                     mov     si,wcPrepInBuf                                  ;input buffer address
                        add     si,11                                           ;skip over JMP and system ID
                        mov     di,Boot                                         ;output buffer address
                        add     di,11                                           ;skip over JMP and system ID
                        mov     cx,19                                           ;length of diskette parameters
                        cld                                                     ;forward string copies
                        rep     movsb                                           ;copy diskette parameters
;
;       Try to write boot sector to diskette.
;
                        mov     cx,EBOOTMAXTRIES                                ;try up to five times
.60                     push    cx                                              ;save remaining tries
                        mov     bx,Boot                                         ;output buffer address
                        mov     dx,0                                            ;head zero, drive zero
                        mov     cx,1                                            ;track zero, sector one
                        mov     al,1                                            ;one sector
                        mov     ah,EBIOSFNWRITESECTOR                           ;write function
                        int     EBIOSINTDISKETTE                                ;attempt the write
                        pop     cx                                              ;restore remaining retries
                        jnc     .100                                            ;skip ahead if successful
                        loop    .60                                             ;try again
                        mov     si,czPrepMsg30                                  ;write-error message address
;
;       Convert the error code to ASCII and display the error message.
;
.70                     push    ax                                              ;save error code
                        mov     al,ah                                           ;copy error code
                        mov     ah,0                                            ;AX = error code
                        mov     dl,10h                                          ;hexadecimal divisor
                        idiv    dl                                              ;AL = hi-order, AH = lo-order
                        or      ax,03030h                                       ;add ASCII zone digits
                        cmp     ah,03Ah                                         ;AH ASCII numeral?
                        jb      .80                                             ;yes, continue
                        add     ah,7                                            ;no, make ASCII 'A'-'F'
.80                     cmp     al,03Ah                                         ;ASCII numeral?
                        jb      .90                                             ;yes, continue
                        add     al,7                                            ;no, make ASCII
.90                     mov     [si+17],ax                                      ;put ASCII error code in message
                        call    BootPrint                                       ;write error message
                        pop     ax                                              ;restore error code
;
;       Display the completion message.
;
.100                    mov     si,czPrepMsgOK                                  ;assume successful completion
                        mov     al,ah                                           ;BIOS return code
                        cmp     al,0                                            ;success?
                        je      .110                                            ;yes, continue
                        mov     si,czPrepMsgErr1                                ;disk parameter error message
                        cmp     al,1                                            ;disk parameter error?
                        je      .110                                            ;yes, continue
                        mov     si,czPrepMsgErr2                                ;address mark not found message
                        cmp     al,2                                            ;address mark not found?
                        je      .110                                            ;yes, continue
                        mov     si,czPrepMsgErr3                                ;protected disk message
                        cmp     al,3                                            ;protected disk?
                        je      .110                                            ;yes, continue
                        mov     si,czPrepMsgErr6                                ;diskette removed message
                        cmp     al,6                                            ;diskette removed?
                        je      .110                                            ;yes, continue
                        mov     si,czPrepMsgErr80                               ;drive timed out message
                        cmp     al,80H                                          ;drive timed out?
                        je      .110                                            ;yes, continue
                        mov     si,czPrepMsgErrXX                               ;unknown error message
.110                    call    BootPrint                                       ;display result message
.120                    mov     ax,04C00H                                       ;terminate with zero result code
                        int     021h                                            ;terminate DOS program
                        ret                                                     ;return (should not execute)
;-----------------------------------------------------------------------------------------------------------------------
;
;       Diskette Preparation Messages
;
;-----------------------------------------------------------------------------------------------------------------------
czPrepMsg10             db      13,10,"CustomOS Boot-Diskette Preparation Program"
                        db      13,10,"Copyright (C) 2010-2018 David J. Walling. All rights reserved."
                        db      13,10
                        db      13,10,"This program overwrites the boot sector of a diskette with startup code that"
                        db      13,10,"will load the operating system into memory when the computer is restarted."
                        db      13,10,"To proceed, place a formatted diskette into drive A: and press the Enter key."
                        db      13,10,"To exit this program without preparing a diskette, press the Escape key."
                        db      13,10,0
czPrepMsg12             db      13,10,"Writing the boot sector to the diskette ..."
                        db      13,10,0
czPrepMsg20             db      13,10,"The error-code .. was returned from the BIOS while reading from the disk."
                        db      13,10,0
czPrepMsg30             db      13,10,"The error-code .. was returned from the BIOS while writing to the disk."
                        db      13,10,0
czPrepMsgOK             db      13,10,"The boot-sector was written to the diskette. Before booting your computer with"
                        db      13,10,"this diskette, make sure that the file OS.COM is copied onto the diskette."
                        db      13,10,0
czPrepMsgErr1           db      13,10,"(01) Invalid Disk Parameter"
                        db      13,10,"This is an internal error caused by an invalid value being passed to a system"
                        db      13,10,"function. The OSBOOT.COM file may be corrupt. Copy or download the file again"
                        db      13,10,"and retry."
                        db      13,10,0
czPrepMsgErr2           db      13,10,"(02) Address Mark Not Found"
                        db      13,10,"This error indicates a physical problem with the floppy diskette. Please retry"
                        db      13,10,"using another diskette."
                        db      13,10,0
czPrepMsgErr3           db      13,10,"(03) Protected Disk"
                        db      13,10,"This error is usually caused by attempting to write to a write-protected disk."
                        db      13,10,"Check the 'write-protect' setting on the disk or retry using using another disk."
                        db      13,10,0
czPrepMsgErr6           db      13,10,"(06) Diskette Removed"
                        db      13,10,"This error may indicate that the floppy diskette has been removed from the"
                        db      13,10,"diskette drive. On some systems, this code may also occur if the diskette is"
                        db      13,10,"'write protected.' Please verify that the diskette is not write-protected and"
                        db      13,10,"is properly inserted in the diskette drive."
                        db      13,10,0
czPrepMsgErr80          db      13,10,"(80) Drive Timed Out"
                        db      13,10,"This error usually indicates that no diskette is in the diskette drive. Please"
                        db      13,10,"make sure that the diskette is properly seated in the drive and retry."
                        db      13,10,0
czPrepMsgErrXX          db      13,10,"(??) Unknown Error"
                        db      13,10,"The error-code returned by the BIOS is not a recognized error. Please consult"
                        db      13,10,"your computer's technical reference for a description of this error code."
                        db      13,10,0
wcPrepInBuf             equ     $
%endif
%ifdef BUILDDISK
;=======================================================================================================================
;
;       File Allocation Tables
;
;       The disk contains two copies of the File Allocation Table (FAT). On our disk, each FAT copy is 1200h bytes in
;       length. Each FAT entry contains the logical number of the next cluster. The first two entries are reserved. Our
;       OS.COM file will be 7400h bytes in length. The first 400h bytes are the 16-bit loader code. The remaining 7000h
;       bytes are the 32-bit kernel code. Our disk parameter table defines a cluster as containing one sector and each
;       sector having 200h bytes. Therefore, our FAT table must reserve 58 clusters for OS.COM. The clusters used by
;       OS.COM, then, will be cluster 2 through 59. The entry for cluster 59 is set to "0fffh" to indicate that it is
;       the last cluster in the chain.
;
;       Every three bytes encode two FAT entries as follows:
;
;       db      0abh,0cdh,0efh  ;even cluster: 0dabh, odd cluster: 0efch
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       FAT copy 1                                                              @disk: 000200   @mem: n/a
;
;-----------------------------------------------------------------------------------------------------------------------
section                 fat1                                                    ;first copy of FAT
                        db      0F0h,0FFh,0FFh, 003h,040h,000h                  ;clusters 0-3           ff0 fff 003 004
                        db      005h,060h,000h, 007h,080h,000h                  ;custters 4-7           005 006 007 008
                        db      009h,0A0h,000h, 00Bh,0C0h,000h                  ;clusters 8-11          009 00a 00b 00c
                        db      00Dh,0E0h,000h, 00Fh,000h,001h                  ;clusters 12-15         00d 00e 00f 010
                        db      011h,020h,001h, 013h,040h,001h                  ;clusters 16-19         011 012 013 014
                        db      015h,060h,001h, 017h,080h,001h                  ;clusters 20-23         015 016 017 018
                        db      019h,0A0h,001h, 01Bh,0C0h,001h                  ;clusters 24-27         019 01a 01b 01c
                        db      01Dh,0E0h,001h, 01Fh,000h,002h                  ;clusters 28-31         01d 01e 01f 020
                        db      021h,020h,002h, 023h,040h,002h                  ;clusters 32-35         021 022 023 024
                        db      025h,060h,002h, 027h,080h,002h                  ;clusters 36-39         025 026 027 028
                        db      029h,0A0h,002h, 02Bh,0C0h,002h                  ;clusters 40-43         029 02A 02B 02C
                        db      02Dh,0E0h,002h, 02Fh,000h,003h                  ;clusters 44-47         02D 02E 02F 030
                        db      031h,020h,003h, 033h,040h,003h                  ;clusters 48-51         031 032 033 034
                        db      035h,060h,003h, 037h,080h,003h                  ;clusters 52-55         035 036 037 038
                        db      039h,0A0h,003h, 03Bh,0F0h,0FFh                  ;clusters 56-59         039 03A 03B FFF
                        times   (9*512)-($-$$) db 0                             ;zero fill to end of section
;-----------------------------------------------------------------------------------------------------------------------
;
;       FAT copy 2                                                              @disk: 001400   @mem: n/a
;
;-----------------------------------------------------------------------------------------------------------------------
section                 fat2                                                    ;second copy of FAT
                        db      0F0h,0FFh,0FFh, 003h,040h,000h                  ;clusters 0-3           ff0 fff 003 004
                        db      005h,060h,000h, 007h,080h,000h                  ;custters 4-7           005 006 007 008
                        db      009h,0A0h,000h, 00Bh,0C0h,000h                  ;clusters 8-11          009 00a 00b 00c
                        db      00Dh,0E0h,000h, 00Fh,000h,001h                  ;clusters 12-15         00d 00e 00f 010
                        db      011h,020h,001h, 013h,040h,001h                  ;clusters 16-19         011 012 013 014
                        db      015h,060h,001h, 017h,080h,001h                  ;clusters 20-23         015 016 017 018
                        db      019h,0A0h,001h, 01Bh,0C0h,001h                  ;clusters 24-27         019 01a 01b 01c
                        db      01Dh,0E0h,001h, 01Fh,000h,002h                  ;clusters 28-31         01d 01e 01f 020
                        db      021h,020h,002h, 023h,040h,002h                  ;clusters 32-35         021 022 023 024
                        db      025h,060h,002h, 027h,080h,002h                  ;clusters 36-39         025 026 027 028
                        db      029h,0A0h,002h, 02Bh,0C0h,002h                  ;clusters 40-43         029 02A 02B 02C
                        db      02Dh,0E0h,002h, 02Fh,000h,003h                  ;clusters 44-47         02D 02E 02F 030
                        db      031h,020h,003h, 033h,040h,003h                  ;clusters 48-51         031 032 033 034
                        db      035h,060h,003h, 037h,080h,003h                  ;clusters 52-55         035 036 037 038
                        db      039h,0A0h,003h, 03Bh,0F0h,0FFh                  ;clusters 56-59         039 03A 03B FFF
                        times   (9*512)-($-$$) db 0                             ;zero fill to end of section
;-----------------------------------------------------------------------------------------------------------------------
;
;       Diskette Directory                                                      @disk: 002600   @mem: n/a
;
;       The disk contains one copy of the diskette directory. Each directory entry is 32 bytes long. Our directory
;       contains only one entry. Unused entries are set to all nulls. The directory immediately follows the second FAT
;       copy.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 dir                                                     ;diskette directory
                        db      "OS      COM"                                   ;file name (must contain spaces)
                        db      020h                                            ;attribute (archive bit set)
                        times   10 db 0                                         ;unused
                        dw      0h                                              ;time
                        db      01000001b                                       ;mmm = 10 MOD 8 = 2; ddddd = 1
                        db      01001001b                                       ;yyyyyyy = 2016-1980 = 36 = 24h; m/8 = 1
                        dw      2                                               ;first cluster
                        dd      07200h                                          ;file size
                        times   (EBOOTDIRENTRIES*32)-($-$$) db 0h               ;zero fill to end of section
%endif
%ifdef BUILDCOM
;=======================================================================================================================
;
;       OS.COM
;
;       The operating system file is assembled at the start of the data area of the floppy disk image, which
;       immediately follows the directory. This corresponds to logical cluster 2, even though the physical address of
;       this sector on the disk varies depending on the disk type. The os.com file consists of two parts, the OS loader
;       and the OS kernel. The Loader is 16-bit code that receives control directly from the boot sector code after the
;       OS.COM file is loaded into memory. The kernel is 32-bit code that receives control after the Loader has
;       initialized protected-mode tables and 32-bit interrupt handlers and switched the CPU into protected mode.
;
;       Our loader addressability is set up according to the following diagram.
;
;       SS -----------> 007b00  +-----------------------------------------------+ SS:0000
;                               |  Boot Stack & Boot PSP (Unused)               |
;                               |  256 = 100h bytes                             |
;       SS:SP --------> 007c00  +-----------------------------------------------+ SS:0100  07b0:0100
;                               |  Boot Sector (vstart=0100h)                   |
;                               |  1 sector = 512 = 200h bytes                  |
;                       007e00  +-----------------------------------------------+
;                               |  File Allocation Table (FAT) I/O Buffer       |
;                               |  9 x 512-byte sectors = 4,608 = 1200h bytes   |
;                               |                                               |
;       CS,DS,ES -----> 008f00  |  Loader PSP (Unused)                          | DS:0000
;                               |                                               |
;       CS:IP --------> 009000  +-----------------------------------------------+ DS:0100  08f0:0100
;                               |  Loader Code                                  |
;                               |  2 sectors = 1024 = 400h bytes                |
;                       009400  +-----------------------------------------------+ DS:0500
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       OS Loader                                                               @disk: 004200   @mem: 009000
;
;       This code is the operating system loader. It resides on the boot disk at the start of the data area, following
;       the directory. The loader occupies several clusters that are mapped in the file allocation tables above.
;       The loader executes 16-bit instructions in real mode. It performs several initialization functions such as
;       determining whether the CPU and other resources are sufficient to run the operating system. If all minimum
;       resources are present, the loader initializes protected mode tables, places the CPU into protected mode and
;       starts the console task. Since the loader was called either from the bootstrap or as a .com file on the boot
;       disk, we can assume that the initial IP is 0x100 and not perform any absolute address fix-ups on our segment
;       registers.
;
;-----------------------------------------------------------------------------------------------------------------------
                        cpu     8086                                            ;assume minimal CPU
section                 loader  vstart=0100h                                    ;use .COM compatible addressing
                        bits    16                                              ;this is 16-bit code
Loader                  push    cs                                              ;use the code segment
                        pop     ds                                              ;...as our data segment
                        push    cs                                              ;use the code segment
                        pop     es                                              ;...as our extra segment
;
;       Write a message to the console so we know we have our addressability established.
;
                        mov     si,czStartingMsg                                ;starting message
                        call    PutTTYString                                    ;display loader message
;
;       Determine the CPU type, generally. Exit if the CPU is not at least an 80386.
;
                        call    GetCPUType                                      ;AL = cpu type
                        mov     si,czCPUErrorMsg                                ;loader error message
                        cmp     al,3                                            ;80386+?
                        jb      LoaderExit                                      ;no, exit with error message
                        cpu     386                                             ;allow 80386 instructions
                        mov     si,czCPUOKMsg                                   ;cpu ok message
                        call    PutTTYString                                    ;display message
;
;       Initialize kernel data areas. The task queue is initialized here because as soon as we enter protected mode,
;       the timer interrupt code will begin inspecting the task queue to determine if a task switch must be made. To
;       start with, we set every 16th queue element to reference the background task selector. This will ensure that
;       the background task, which updates the visible clock on the console, will be called at least once per second.
;
                        push    EKRNDATASEG                                     ;load kernel data segment address ...
                        pop     es                                              ;... into extra segment reg
                        mov     di,wwTaskQueue                                  ;task queue address
                        mov     cx,64                                           ;outer loop
.10                     push    cx                                              ;save remaining outer iterations
                        mov     cx,3                                            ;inner loop
                        mov     ax,EGDTCONSOLETSS                               ;console task state segment selector
                        cld                                                     ;forward strings
                        rep     stosw                                           ;store selectors in task queue
                        mov     ax,ESELBACKGROUNDTSS                            ;background task state segment selector
                        stosw                                                   ;store selector in task queue
                        pop     cx                                              ;restore remaining outer iterations
                        loop    .10                                             ;next
                        xor     ax,ax                                           ;zero register
                        mov     cl,4                                            ;remaining words to reset
                        rep     stosw                                           ;reset remaining kernel data
;
;       Fixup the GDT descriptor for the current (loader) code segment.
;
                        mov     si,EKRNCODESRCADR                               ;GDT offset
                        mov     ax,cs                                           ;AX:SI = gdt source
                        rol     ax,4                                            ;AX = phys addr bits 11-0,15-12
                        mov     cl,al                                           ;CL = phys addr bits 3-0,15-12
                        and     al,0F0h                                         ;AL = phys addr bits 11-0
                        and     cl,00Fh                                         ;CL = phys addr bits 15-12
                        mov     word [si+EGDTLOADERCODE+2],ax                   ;lo-order loader code (0-15)
                        mov     byte [si+EGDTLOADERCODE+4],cl                   ;lo-order loader code (16-23)
                        mov     si,czGDTOKMsg                                   ;GDT prepared message
                        call    PutTTYString                                    ;display message
;
;       Move the 32-bit kernel to its appropriate memory location.
;
                        push    EKRNCODESEG                                     ;use kernel code segment ...
                        pop     es                                              ;... as target segment
                        xor     di,di                                           ;ES:DI = target address
                        mov     si,EKRNCODESRCADR                               ;DS:SI = source address
                        mov     cx,EKRNCODELEN                                  ;CX = kernel size
                        cld                                                     ;forward strings
                        rep     movsb                                           ;copy kernel image
                        mov     si,czKernelLoadedMsg                            ;kernel moved message
                        call    PutTTYString                                    ;display message
;
;       Switch to protected mode.
;
                        xor     si,si                                           ;ES:SI = gdt addr
                        mov     ss,si                                           ;protected mode ss
                        mov     sp,EKRNCODEBASE                                 ;initial stack immediate before code
                        mov     ah,EBIOSFNINITPROTMODE                          ;initialize protected mode fn.
                        mov     bx,02028h                                       ;BH,BL = IRQ int bases
                        mov     dx,001Fh                                        ;outer delay loop count
.20                     mov     cx,0FFFFh                                       ;inner delay loop count
                        loop    $                                               ;wait out pending interrupts
                        dec     dx                                              ;restore outer loop count
                        jnz     .20                                             ;continue outer loop
                        int     EBIOSINTMISC                                    ;call BIOS to set protected mode
;
;       Enable hardware and maskable interrupts.
;
                        xor     al,al                                           ;enable all registers code
                        out     EPICPORTPRI1,al                                 ;enable all primary 8259A ints
                        out     EPICPORTSEC1,al                                 ;enable all secondary 8259A ints
                        sti                                                     ;enable maskable interrupts
;
;       Load the Task State Segment (TSS) and Local Descriptor Table (LDT) registers and jump to the initial task.
;
                        ltr     [cs:cwLoaderTSS]                                ;load task register
                        lldt    [cs:cwLoaderLDT]                                ;load local descriptor table register
                        jmp     EGDTCONSOLETSS:0                                ;jump to task state segment selector
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        LoaderExit
;
;       Description:    This routine displays the message at DS:SI, waits for a keypress and resets the system.
;
;       In:             DS:SI   string address
;
;-----------------------------------------------------------------------------------------------------------------------
LoaderExit              call    PutTTYString                                    ;display error message
;
;       Now we want to wait for a keypress. We can use a keyboard interrupt function for this (INT 16h, AH=0).
;       However, some hypervisor BIOS implementations have been seen to implement the "wait" as simply a fast
;       iteration of the keyboard status function call (INT 16h, AH=1), causing a max CPU condition. So, instead,
;       we will use the keyboard status call and iterate over a halt (HLT) instruction until a key is pressed.
;       By convention, we enable maskable interrupts with STI before issuing HLT, so as not to catch fire.
;
.30                     mov     ah,EBIOSFNKEYSTATUS                             ;keyboard status function
                        int     EBIOSINTKEYBOARD                                ;call BIOS keyboard interrupt
                        jnz     .40                                             ;exit if key pressed
                        sti                                                     ;enable maskable interrupts
                        hlt                                                     ;wait for interrupt
                        jmp     .30                                             ;repeat until keypress
;
;       Now that a key has been pressed, we signal the system to restart by driving the B0 line on the 8042
;       keyboard controller low (OUT 64h,0feh). The restart may take some microseconds to kick in, so we issue
;       HLT until the system resets.
;
.40                     mov     al,EKEYBCMDRESET                                ;8042 pulse output port pin
                        out     EKEYBPORTSTAT,al                                ;drive B0 low to restart
.50                     sti                                                     ;enable maskable interrupts
                        hlt                                                     ;stop until reset, int, nmi
                        jmp     .50                                             ;loop until restart kicks in
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        GetCPUType
;
;       Description:    The loader needs only to determine that the cpu is at least an 80386 or an equivalent. Note that
;                       the CPUID instruction was not introduced until the SL-enhanced 80486 and Pentium processors, so
;                       to distinguish whether we have at least an 80386, other means must be used.
;
;       Out:            AX      0 = 808x, v20, etc.
;                               1 = 80186
;                               2 = 80286
;                               3 = 80386
;
;-----------------------------------------------------------------------------------------------------------------------
GetCPUType              mov     al,1                                            ;AL = 1
                        mov     cl,32                                           ;shift count
                        shr     al,cl                                           ;try a 32-bit shift
                        or      al,al                                           ;did the shift happen?
                        jz      .10                                             ;yes, cpu is 808x, v20, etc.
                        cpu     186
                        push    sp                                              ;save stack pointer
                        pop     cx                                              ;...into cx
                        cmp     cx,sp                                           ;did sp decrement before push?
                        jne     .10                                             ;yes, cpu is 80186
                        cpu     286
                        inc     ax                                              ;AX = 2
                        sgdt    [cbLoaderGDT]                                   ;store gdt reg in work area
                        mov     cl,[cbLoaderGDTHiByte]                          ;CL = hi-order byte
                        inc     cl                                              ;was hi-byte of GDTR 0xff?
                        jz      .10                                             ;yes, cpu is 80286
                        inc     ax                                              ;AX = 3
.10                     ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutTTYString
;
;       Description:    This routine sends a NUL-terminated string of characters to the TTY output device. We use the
;                       TTY output function of the BIOS video interrupt, passing the address of the string in DS:SI
;                       and the BIOS teletype function code in AH. After a return from the BIOS interrupt, we repeat
;                       for the next string character until a NUL is found. Note that we clear the direction flag (DF)
;                       with CLD before the first LODSB. The direction flag is not guaranteed to be preseved between
;                       calls within the OS. However, the "int" instruction does store the EFLAGS register on the
;                       stack and restores it on return. Therefore, clearing the direction flag before subsequent calls
;                       to LODSB is not needed.
;
;       In:             DS:SI   address of string
;
;       Out:            DF      0
;                       ZF      1
;                       AL      0
;
;-----------------------------------------------------------------------------------------------------------------------
PutTTYString            cld                                                     ;forward strings
.10                     lodsb                                                   ;load next byte at DS:SI in AL
                        test    al,al                                           ;end of string?
                        jz      .20                                             ;... yes, exit our loop
                        mov     ah,EBIOSFNTTYOUTPUT                             ;BIOS teletype function
                        int     EBIOSINTVIDEO                                   ;call BIOS display interrupt
                        jmp     .10                                             ;repeat until done
.20                     ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Loader Data
;
;       The loader data is updated to include constants defining the initial (Loader) TSS and LDT selectors in the
;       GDT, a work area to build the GDTR, and additional text messages.
;
;-----------------------------------------------------------------------------------------------------------------------
                        align   2
cwLoaderLDT             dw      EGDTLOADERLDT                                   ;loader local descriptor table selector
cwLoaderTSS             dw      EGDTLOADERTSS                                   ;loader task state segment selector
cbLoaderGDT             times   5 db 0                                          ;6-byte GDTR work area
cbLoaderGDTHiByte       db      0                                               ;hi-order byte
czCPUErrorMsg           db      "The operating system requires an i386 or later processor.",13,10
                        db      "Please press any key to restart the computer.",13,10,0
czCPUOKMsg              db      "CPU OK",13,10,0                                ;CPU level ok message
czGDTOKMsg              db      "GDT prepared",13,10,0                          ;global descriptor table ok message
czKernelLoadedMsg       db      "Kernel loaded",13,10,0                         ;kernel loaded message
czStartingMsg           db      "Starting OS",13,10,0                           ;starting message
                        times   1024-($-$$) db 0h                               ;zero fill to end of sector
;=======================================================================================================================
;
;       OS Kernel                                                               @disk: 004600   @mem: 001000
;
;       This code is the operating system kernel. It resides on the boot disk image as part of the OS.COM file,
;       following the 16-bit loader code above. The Kernel executes only 32-bit code in protected mode and contains one
;       task, the Console, which performs a loop accepting user input from external devices (keyboard, etc.), processes
;       commands and displays ouput to video memory. The Kernel also includes a library of system functions accessible
;       through software interrupt 58 (30h). Finally, the Kernel provides CPU and hardware interrupt handlers.
;
;=======================================================================================================================
;=======================================================================================================================
;
;       Kernel Tables
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Global Descriptor Table                                                 @disk: 004600   @mem: 001000
;
;       The Global Descriptor Table (GDT) consists of eight-byte descriptors that define reserved memory areas. The
;       first descriptor must be all nulls.
;
;       6   5         4         3         2         1         0
;       3210987654321098765432109876543210987654321098765432109876543210
;       ----------------------------------------------------------------
;       h......hffffmmmma......ab......................bn..............n
;       00000000                        all areas have base addresses below 2^24
;               0100                    (0x4) 32-bit single-byte granularity
;               1100                    (0xC) 32-bit 4KB granularity
;                   1001                present, ring-0, selector
;
;       h...h   hi-order base address (bits 24-31)
;       ffff    flags
;       mmmm    hi-order limit (bits 16-19)
;       a...a   access
;       b...b   lo-order base address (bits 0-23)
;       n...n   lo-order limit (bits 0-15)
;
;-----------------------------------------------------------------------------------------------------------------------
section                 gdt                                                     ;global descriptor table
                        dq      0000000000000000h                               ;00 required null selector
                        dq      00409300100007FFh                               ;08 2KB  writable data  (GDT alias)
                        dq      00409300180007FFh                               ;10 2KB  writable data  (IDT alias)
                        dq      00CF93000000FFFFh                               ;18 4GB  writable data  (kernel)     DS:
                        dq      0040930B80000FFFh                               ;20 4KB  writable data  (CGA)        ES:
                        dq      0040930000000FFFh                               ;28 4KB  writable stack (Loader)     SS:
                        dq      00009B000000FFFFh                               ;30 64KB readable code  (loader)     CS:
                        dq      00009BFF0000FFFFh                               ;38 64KB readable code  (BIOS)
                        dq      004093000400FFFFh                               ;40 64KB writable data  (BIOS)
                        dq      00409B0020001FFFh                               ;48 8KB  readable code  (kernel)
                        dq      004082000F00007Fh                               ;50 80B  writable LDT   (loader)
                        dq      004089000F80007Fh                               ;58 80B  writable TSS   (loader)
                        dq      004082004700007Fh                               ;60 80B  writable LDT   (console)
                        dq      004089004780007Fh                               ;88 80B  writable TSS   (console)
                        dq      004082006700007Fh                               ;70 80B  writable LDT   (background)
                        dq      004089006780007Fh                               ;78 80B  writable TSS   (background)
                        dq      00409300480007FFh                               ;80 2KB  foreground task message queue
                        times   2048-($-$$) db 0h                               ;zero fill to end of section
;-----------------------------------------------------------------------------------------------------------------------
;
;       Interrupt Descriptor Table                                              @disk: 004e00   @mem: 001800
;
;       The Interrupt Descriptor Table (IDT) consists of one eight-byte entry (descriptor) for each interrupt. The
;       descriptors here are of two kinds, interrupt gates and trap gates. The "mint" and "mtrap" macros define the
;       descriptors, taking only the name of the entry point for the code handling the interrupt.
;
;       6   5         4         3         2         1         0
;       3210987654321098765432109876543210987654321098765432109876543210
;       ----------------------------------------------------------------
;       h..............hPzzStttt00000000S..............Sl..............l
;
;       h...h   high-order offset (bits 16-31)
;       P       present (0=unused interrupt)
;       zz      descriptor privilege level
;       S       storage segment (must be zero for IDT)
;       tttt    type: 0101=task, 1110=int, 1111=trap
;       S...S   handling code selector in GDT
;       l...l   lo-order offset (bits 0-15)
;
;-----------------------------------------------------------------------------------------------------------------------
section                 idt                                                     ;interrupt descriptor table
                        mint    dividebyzero                                    ;00 divide by zero
                        mint    singlestep                                      ;01 single step
                        mint    nmi                                             ;02 non-maskable
                        mint    break                                           ;03 break
                        mint    into                                            ;04 into
                        mint    bounds                                          ;05 bounds
                        mint    badopcode                                       ;06 bad op code
                        mint    nocoproc                                        ;07 no coprocessor
                        mint    doublefault                                     ;08 double-fault
                        mint    operand                                         ;09 operand
                        mint    badtss                                          ;0a bad TSS
                        mint    notpresent                                      ;0b not-present
                        mint    stacklimit                                      ;0c stack limit
                        mint    protection                                      ;0d general protection fault
                        mint    int14                                           ;0e (reserved)
                        mint    int15                                           ;0f (reserved)
                        mint    coproccalc                                      ;10 (reserved)
                        mint    int17                                           ;11 (reserved)
                        mint    int18                                           ;12 (reserved)
                        mint    int19                                           ;13 (reserved)
                        mint    int20                                           ;14 (reserved)
                        mint    int21                                           ;15 (reserved)
                        mint    int22                                           ;16 (reserved)
                        mint    int23                                           ;17 (reserved)
                        mint    int24                                           ;18 (reserved)
                        mint    int25                                           ;19 (reserved)
                        mint    int26                                           ;1a (reserved)
                        mint    int27                                           ;1b (reserved)
                        mint    int28                                           ;1c (reserved)
                        mint    int29                                           ;1d (reserved)
                        mint    int30                                           ;1e (reserved)
                        mint    int31                                           ;1f (reserved)
                        mtrap   clocktick                                       ;20 IRQ0 clock tick
                        mtrap   keyboard                                        ;21 IRQ1 keyboard
                        mtrap   iochannel                                       ;22 IRQ2 second 8259A cascade
                        mtrap   com2                                            ;23 IRQ3 com2
                        mtrap   com1                                            ;24 IRQ4 com1
                        mtrap   lpt2                                            ;25 IRQ5 lpt2
                        mtrap   diskette                                        ;26 IRQ6 diskette
                        mtrap   lpt1                                            ;27 IRQ7 lpt1
                        mtrap   rtclock                                         ;28 IRQ8 real-time clock
                        mtrap   retrace                                         ;29 IRQ9 CGA vertical retrace
                        mtrap   irq10                                           ;2a IRQA (reserved)
                        mtrap   irq11                                           ;2b IRQB (reserved)
                        mtrap   ps2mouse                                        ;2c IRQC ps/2 mouse
                        mtrap   coprocessor                                     ;2d IRQD coprocessor
                        mtrap   fixeddisk                                       ;2e IRQE fixed disk
                        mtrap   irq15                                           ;2f IRQF (reserved)
                        mtrap   svc                                             ;30 OS services
                        times   2048-($-$$) db 0h                               ;zero fill to end of section
;=======================================================================================================================
;
;       Interrupt Handlers                                                      @disk: 005600   @mem:  002000
;
;       Interrupt handlers are 32-bit routines that receive control either in response to events or by direct
;       invocation from other kernel code. The interrupt handlers are of three basic types. CPU interrupts occur when a
;       CPU exception is detected. Hardware interrupts occur when an external device (timer, keyboard, disk, etc.)
;       signals the CPU on an interrupt request line (IRQ). Software interrupts occur when directly called by other code
;       using the INT instruction. Each interrupt handler routine is defined by using our "menter" macro, which simply
;       establishes a label defining the offset address of the entry point from the start of the kernel section. This
;       label is referenced in the "mint" and "mtrap" macros found in the IDT to specify the address of the handlers.
;
;=======================================================================================================================
section                 kernel  vstart=0h                                       ;data offsets relative to 0
                        cpu     386                                             ;allow 80386 instructions
                        bits    32                                              ;this is 32-bit code
;=======================================================================================================================
;
;       CPU Interrupt Handlers
;
;       The first 32 entries in the Interrupt Descriptor Table are reserved for use by CPU interrupts. The handling
;       of these interrupts is expanded here to display the contents of registers at the time of the interrupt.
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT0    Divide By Zero
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  dividebyzero                                    ;divide by zero
                        push    0                                               ;store interrupt nbr
                        push    czIntDivideByZero                               ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT1    Single Step
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  singlestep                                      ;single step
                        push    1                                               ;store interrupt nbr
                        push    czIntSingleStep                                 ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT2    Non-Maskable Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  nmi                                             ;non-maskable
                        push    2                                               ;store interrupt nbr
                        push    czIntNonMaskable                                ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT3    Break
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  break                                           ;break
                        push    3                                               ;store interrupt nbr
                        push    czIntBreak                                      ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT4    Into
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  into                                            ;into
                        push    4                                               ;store interrupt nbr
                        push    czIntInto                                       ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT5    Bounds
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  bounds                                          ;bounds
                        push    5                                               ;store interrupt nbr
                        push    czIntBounds                                     ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT6    Bad Operation Code
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  badopcode                                       ;bad opcode interrupt
                        push    6                                               ;store interrupt nbr
                        push    czIntBadOpCode                                  ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT7    No Coprocessor
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  nocoproc                                        ;no coprocessor interrupt
                        push    7                                               ;store interrupt nbr
                        push    czIntNoCoprocessor                              ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT8    Double Fault
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  doublefault                                     ;doublefault interrupt
                        push    8                                               ;store interrupt nbr
                        push    czIntDoubleFault                                ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT9    Operand
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  operand                                         ;operand interrupt
                        push    9                                               ;store interrupt nbr
                        push    czIntOperand                                    ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT10   Bad Task State Segment
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  badtss                                          ;bad TSS interrupt
                        push    10                                              ;store interrupt nbr
                        push    czIntBadTSS                                     ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT11   Not Present
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  notpresent                                      ;not present interrupt
                        push    11                                              ;store interrupt nbr
                        push    czIntNotPresent                                 ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT12   Stack Limit
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  stacklimit                                      ;stack limit interrupt
                        push    12                                              ;store interrupt nbr
                        push    czIntStackLimit                                 ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT13   General Protection Fault
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  protection                                      ;protection fault interrupt
                        push    13                                              ;store interrupt nbr
                        push    czIntProtection                                 ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT14   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int14                                           ;(reserved)
                        push    14                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT15   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int15                                           ;(reserved)
                        push    15                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT16   Coprocessor Calculation
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  coproccalc                                      ;coprocessor calculation
                        push    16                                              ;store interrupt nbr
                        push    czIntCoprocessorCalc                            ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT17   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int17                                           ;(reserved)
                        push    17                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT18   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int18                                           ;(reserved)
                        push    18                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT19   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int19                                           ;(reserved)
                        push    19                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT20   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int20                                           ;(reserved)
                        push    20                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT21   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int21                                           ;(reserved)
                        push    21                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT22   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int22                                           ;(reserved)
                        push    22                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT23   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int23                                           ;(reserved)
                        push    23                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT24   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int24                                           ;(reserved)
                        push    24                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT25   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int25                                           ;(reserved)
                        push    25                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT26   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int26                                           ;(reserved)
                        push    26                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT27   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int27                                           ;(reserved)
                        push    27                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT28   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int28                                           ;(reserved)
                        push    28                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT29   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int29                                           ;(reserved)
                        push    29                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT30   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int30                                           ;(reserved)
                        push    30                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT31   Reserved
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  int31                                           ;(reserved)
                        push    31                                              ;store interrupt nbr
                        push    czIntReserved                                   ;store message offset
                        jmp     ReportInterrupt                                 ;report interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ReportInterrupt
;
;       Description:    This routine will be used to respond to processor interrupts that are not otherwise handled.
;                       At this stage, we simply restore the stack and return from the interrupt.
;
;       In:             [esp+16]        eflags                                  stored by interrupt call
;                       [esp+12]        cs                                      stored by interrupt call
;                       [esp+8]         eip                                     stored by interrupt call
;                       [esp+4]         interrupt number (0-31)                 stored by push instruction
;                       [esp+0]         error message address                   stored by push instructions
;
;       Out:            N/A             This routine does not exit.
;
;-----------------------------------------------------------------------------------------------------------------------
ReportInterrupt         push    ds                                              ;save DS at time of interrupt
                        push    es                                              ;save ES at time of interrupt
                        pushad                                                  ;save EAX,ECX,EDX,EBX,EBP,ESP,ESI,EDI
                        mov     ebp,esp                                         ;ebp --> [EDI]
;
;       Addressability to registers at the time of the interrupt is now established as:
;
;                       [ebp+56]        eflags
;                       [ebp+52]        cs
;                       [ebp+48]        eip
;                       [ebp+44]        interrupt number (0-31)
;                       [ebp+40]        error message address
;                       [ebp+36]        ds
;                       [ebp+32]        es
;                       [ebp+28]        eax
;                       [ebp+24]        ecx
;                       [ebp+20]        edx
;                       [ebp+16]        ebx
;                       [ebp+12]        esp
;                       [ebp+8]         ebp
;                       [ebp+4]         esi
;                       [ebp+0]         edi
;
                        push    cs                                              ;load code selector ...
                        pop     ds                                              ;... into DS
                        push    EGDTCGA                                         ;load CGA memory selector ...
                        pop     es                                              ;... into ES
;
;       Display the interrupt report boundary box
;
                        mov     cl,13                                           ;column
                        mov     ch,6                                            ;row
                        mov     dl,50                                           ;width
                        mov     dh,8                                            ;height
                        mov     bh,07h                                          ;attribute
                        call    DrawTextDialogBox                               ;draw text dialog box
;
;       Display the report header
;
                        mov     cl,15                                           ;column
                        mov     ch,7                                            ;row
                        mov     esi,czIntHeader                                 ;interrupt message header
                        call    SetConsoleString                                ;draw text string
;
;       Display the interrupt description label
;
                        mov     cl,15                                           ;column
                        mov     ch,8                                            ;row
                        mov     esi,czIntLabel                                  ;interrupt message description lead
                        call    SetConsoleString                                ;draw text string
;
;       Display the interrupt number
;
                        mov     eax,[ebp+44]                                    ;interrupt number
                        mov     cl,26                                           ;column
                        mov     ch,8                                            ;row
                        call    PutConsoleHexByte                               ;draw ASCII hex byte
;
;       Display the interrupt name
;
                        mov     cl,29                                           ;column
                        mov     ch,8                                            ;row
                        mov     esi,[ebp+40]                                    ;interrupt-specific message
                        call    SetConsoleString                                ;display interrupt description
;
;       Display the register values header
;
                        mov     cl,15                                           ;column
                        mov     ch,10                                           ;row
                        mov     esi,czIntRegsHeader                             ;interrupt registers header
                        call    SetConsoleString                                ;draw text string
;
;       Display the EAX register label and value
;
                        mov     cl,15                                           ;column
                        mov     ch,11                                           ;row
                        mov     esi,czIntEAX                                    ;register EAX label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+28]                                    ;EAX value at interrupt
                        mov     cl,19                                           ;column
                        mov     ch,11                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Display the ECX register label and value
;
                        mov     cl,15                                           ;column
                        mov     ch,12                                           ;row
                        mov     esi,czIntECX                                    ;label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+24]                                    ;ECX value at interrupt
                        mov     cl,19                                           ;column
                        mov     ch,12                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Display the EDX register label and value
;
                        mov     cl,15                                           ;column
                        mov     ch,13                                           ;row
                        mov     esi,czIntEDX                                    ;label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+20]                                    ;EDX value at interrupt
                        mov     cl,19                                           ;column
                        mov     ch,13                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Display the EBX register label and value
;
                        mov     cl,15                                           ;column
                        mov     ch,14                                           ;row
                        mov     esi,czIntEBX                                    ;label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+16]                                    ;EBX value at interrupt
                        mov     cl,19                                           ;column
                        mov     ch,14                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Display the ESI register label and value
;
                        mov     cl,29                                           ;column
                        mov     ch,11                                           ;row
                        mov     esi,czIntESI                                    ;label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+4]                                     ;ESI
                        mov     cl,33                                           ;column
                        mov     ch,11                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Display the EDI register label and value
;
                        mov     cl,29                                           ;column
                        mov     ch,12                                           ;row
                        mov     esi,czIntEDI                                    ;label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+0]                                     ;EDI
                        mov     cl,33                                           ;column
                        mov     ch,12                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Display the EBP register label and value
;
                        mov     cl,29                                           ;column
                        mov     ch,13                                           ;row
                        mov     esi,czIntEBP                                    ;label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+8]                                     ;EBP
                        mov     cl,33                                           ;column
                        mov     ch,13                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Display the DS register label and value
;
                        mov     cl,42                                           ;column
                        mov     ch,11                                           ;row
                        mov     esi,czIntDS                                     ;label
                        call    SetConsoleString                                ;draw label
                        xor     eax,eax                                         ;zero register
                        mov     ax,[ebp+36]                                     ;DS
                        mov     cl,46                                           ;column
                        mov     ch,11                                           ;row
                        call    PutConsoleHexWord                               ;draw ASCII hex word
;
;       Display the ES register label and value
;
                        mov     cl,42                                           ;column
                        mov     ch,12                                           ;row
                        mov     esi,czIntES                                     ;label
                        call    SetConsoleString                                ;draw label
                        xor     eax,eax                                         ;zero register
                        mov     ax,[ebp+32]                                     ;ES
                        mov     cl,46                                           ;column
                        mov     ch,12                                           ;row
                        call    PutConsoleHexWord                               ;draw ASCII hex word
;
;       Display the SS register label and value
;
                        mov     cl,42                                           ;column
                        mov     ch,13                                           ;row
                        mov     esi,czIntSS                                     ;label
                        call    SetConsoleString                                ;draw label
                        xor     eax,eax                                         ;zero register
                        mov     ax,ss                                           ;SS
                        mov     cl,46                                           ;column
                        mov     ch,13                                           ;row
                        call    PutConsoleHexWord                               ;draw ASCII hex word
;
;       Display the CS register lable and value
;
                        mov     cl,42                                           ;column
                        mov     ch,14                                           ;row
                        mov     esi,czIntCS                                     ;label
                        call    SetConsoleString                                ;draw label
                        xor     eax,eax                                         ;zero register
                        mov     ax,[ebp+52]                                     ;CS
                        mov     cl,46                                           ;column
                        mov     ch,14                                           ;row
                        call    PutConsoleHexWord                               ;draw ASCII hex word
;
;       Display the EFLAGS register label and value
;
                        mov     cl,51                                           ;column
                        mov     ch,11                                           ;row
                        mov     esi,czIntEFLAGS                                 ;label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+56]                                    ;EFLAGS
                        mov     cl,55                                           ;column
                        mov     ch,11                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Display the ESP register label and value
;
                        mov     cl,51                                           ;column
                        mov     ch,13                                           ;row
                        mov     esi,czIntESP                                    ;label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+12]                                    ;ESP
                        mov     cl,55                                           ;column
                        mov     ch,13                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Display the EIP register label and value
;
                        mov     cl,51                                           ;column
                        mov     ch,14                                           ;row
                        mov     esi,czIntEIP                                    ;label
                        call    SetConsoleString                                ;draw label
                        mov     eax,[ebp+48]                                    ;EIP
                        mov     cl,55                                           ;column
                        mov     ch,14                                           ;row
                        call    PutConsoleHexDword                              ;draw ASCII hex doubleword
;
;       Halt and loop until reset
;
.10                     sti                                                     ;enable maskable interrupts
                        hlt                                                     ;halt processor
                        jmp     .10                                             ;resume on interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       Processor Interrupt Name Strings
;
;-----------------------------------------------------------------------------------------------------------------------
czIntDivideByZero       db      "Division by zero",0
czIntSingleStep         db      "Single step",0
czIntNonMaskable        db      "Non-maskable interrupt",0
czIntBreak              db      "Break",0
czIntInto               db      "Into",0
czIntBounds             db      "Bounds",0
czIntBadOpCode          db      "Bad Operation Code",0
czIntNoCoprocessor      db      "No Coprocessor",0
czIntDoubleFault        db      "Double Fault",0
czIntOperand            db      "Operand",0
czIntBadTSS             db      "Bad Task State Segment",0
czIntNotPresent         db      "Not Present",0
czIntStackLimit         db      "Stack Limit",0
czIntProtection         db      "General Protection Fault",0
czIntCoprocessorCalc    db      "Coprocessor Calculation",0
czIntReserved           db      "Reserved",0
;-----------------------------------------------------------------------------------------------------------------------
;
;       Processor Interrupt Handling Strings
;
;-----------------------------------------------------------------------------------------------------------------------
czIntHeader             db      "An unhandled processor interrupt has occurred:",0
czIntLabel              db      "Interrupt #",0
czIntRegsHeader         db      "Registers at the time of the interrupt:",0
czIntEAX                db      "EAX:",0
czIntECX                db      "ECX:",0
czIntEDX                db      "EDX:",0
czIntEBX                db      "EBX:",0
czIntESI                db      "ESI:",0
czIntEDI                db      "EDI:",0
czIntEBP                db      "EBP:",0
czIntESP                db      "ESP:",0
czIntDS                 db      " DS:",0
czIntES                 db      " ES:",0
czIntSS                 db      " SS:",0
czIntCS                 db      " CS:",0
czIntEFLAGS             db      "FLG:",0
czIntEIP                db      "EIP:",0
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        DrawTextDialogBox
;
;       Description:    This routine opens a text-mode dialog box with an ASCII border.
;
;       In:             CL      upper left column (0-79)
;                       CH      upper left row (0-24)
;                       DL      column width, excluding border
;                       DH      row height, excluding border
;                       BH      color attribute
;
;-----------------------------------------------------------------------------------------------------------------------
DrawTextDialogBox       push    ecx                                             ;save non-volatile regs
                        push    esi                                             ;
                        push    edi                                             ;
                        push    es                                              ;
                        push    EGDTCGA                                         ;load CGA selector ...
                        pop     es                                              ;... into ES
;
;       Compute target display offset
;
                        xor     eax,eax                                         ;zero register
                        mov     al,ch                                           ;row
                        mov     ah,ECONROWBYTES                                 ;mulitplicand
                        mul     ah                                              ;row offset
                        add     al,cl                                           ;add column
                        adc     ah,0                                            ;add overflow
                        add     al,cl                                           ;add column
                        adc     ah,0                                            ;add overflow
                        mov     edi,eax                                         ;target row offset
;
;       Display top border row
;
                        push    edi                                             ;save target row offset
                        mov     ah,bh                                           ;attribute
                        mov     al,EASCIIBORDSGLUPRLFT                          ;upper-left single border
                        stosw                                                   ;display character and attribute
                        mov     al,EASCIIBORDSGLHORZ                            ;horizontal single border
                        xor     ecx,ecx                                         ;zero register
                        mov     cl,dl                                           ;width, excluding border
                        rep     stosw                                           ;display horizontal border
                        mov     al,EASCIIBORDSGLUPRRGT                          ;upper-right single border
                        stosw                                                   ;display character and attribute
                        pop     edi                                             ;restore target row offset
                        add     edi,ECONROWBYTES                                ;next row
;
;       Display dialog box body rows
;
                        xor     ecx,ecx                                         ;zero register
                        mov     cl,dh                                           ;height, excluding border
.10                     push    ecx                                             ;save remaining rows
                        push    edi                                             ;save target row offset
                        mov     ah,bh                                           ;attribute
                        mov     al,EASCIIBORDSGLVERT                            ;vertical single border
                        stosw                                                   ;display character and attribute
                        mov     al,EASCIISPACE                                  ;space
                        xor     ecx,ecx                                         ;zero register
                        mov     cl,dl                                           ;width, excluding border
                        rep     stosw                                           ;display row
                        mov     al,EASCIIBORDSGLVERT                            ;vertical single border
                        stosw                                                   ;display character and attribute
                        pop     edi                                             ;restore target row offset
                        add     edi,ECONROWBYTES                                ;next row
                        pop     ecx                                             ;remaining rows
                        loop    .10                                             ;next row
;
;       Display bottom border row
;
                        push    edi                                             ;save target row offset
                        mov     ah,bh                                           ;attribute
                        mov     al,EASCIIBORDSGLLWRLFT                          ;lower-left single border
                        stosw                                                   ;display character and attribute
                        mov     al,EASCIIBORDSGLHORZ                            ;horizontal single border
                        xor     ecx,ecx                                         ;zero register
                        mov     cl,dl                                           ;width, excluding border
                        rep     stosw                                           ;display horizontal border
                        mov     al,EASCIIBORDSGLLWRRGT                          ;lower-right single border
                        stosw                                                   ;display character and attribute
                        pop     edi                                             ;restore target row offset
                        add     edi,ECONROWBYTES                                ;next row
;
;       Restore and return
;
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        ret                                                     ;return
;=======================================================================================================================
;
;       Hardware Device Interupts
;
;       The next 16 interrupts are defined as our hardware interrupts. These interrupts vectors (20h-2Fh) are mapped to
;       the hardware interrupts IRQ0-IRQF by the BIOS when the call to the BIOS is made invoking BIOS function 89h
;       (BX=2028h).
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ0    Clock Tick Interrupt
;
;       PC compatible systems contain or emulate the function of the Intel 8253 Programmable Interval Timer (PIT).
;       Channel 0 of this chip decrements an internal counter to zero and then issues a hardware interrupt. The default
;       rate at which IRQ0 occurs is approximately 18.2 times per second or, more accurately, 1,573,040 times per day.
;
;       Every time IRQ0 occurs, a counter at 40:6c is incremented. When the number of ticks reaches the maximum for one
;       day, the counter is set to zero and the number of days counter at 40:70 is incremented.
;
;       This handler also decrements the floppy drive motor count at 40:40 if it is not zero. When this count reaches
;       zero, the floppy disk motors are turned off.
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  clocktick                                       ;clock tick interrupt
                        push    eax                                             ;save non-volatile regs
                        push    edx                                             ;
                        push    ds                                              ;
;
;       Update the clock tick count and the elapsed days as needed.
;
                        push    EGDTOSDATA                                      ;load OS data selector ...
                        pop     ds                                              ;... into data segment register
                        mov     eax,[wdClockTicks]                              ;EAX = clock ticks
                        inc     eax                                             ;increment clock ticks
                        cmp     eax,EPITDAYTICKS                                ;clock ticks per day?
                        jb      irq0.10                                         ;no, skip ahead
                        inc     byte [wbClockDays]                              ;increment clock days
                        xor     eax,eax                                         ;reset clock ticks
irq0.10                 mov     dword [wdClockTicks],eax                        ;save clock ticks
;
;       Decrement floppy disk motor timeout.
;
                        cmp     byte [wbFDCMotor],0                             ;floppy motor timeout?
                        je      irq0.20                                         ;yes, skip ahead
                        dec     byte [wbFDCMotor]                               ;decrement motor timeout
                        jnz     irq0.20                                         ;skip ahead if non-zero
;
;       Turn off the floppy disk motor if appropriate.
;
                        sti                                                     ;enable maskable interrupts
irq0.15                 mov     dh,EFDCPORTHI                                   ;FDC controller port hi
                        mov     dl,EFDCPORTLOSTAT                               ;FDC main status register
                        in      al,dx                                           ;FDC main status byte
                        test    al,EFDCSTATBUSY                                 ;test FDC main status for busy
                        jnz     irq0.15                                         ;wait while busy
                        mov     al,EFDCMOTOROFF                                 ;motor-off / enable/ DMA setting
                        mov     byte [wbFDCControl],al                          ;save motor-off setting
                        mov     dh,EFDCPORTHI                                   ;FDC port hi
                        mov     dl,EFDCPORTLOOUT                                ;FDC digital output register
                        out     dx,al                                           ;turn motor off
;
;       Signal the end of the hardware interrupt.
;
irq0.20                 call    PutPrimaryEndOfInt                              ;send end-of-interrupt to PIC
;
;       Determine if a task switch is appropriate
;
                        cmp     byte [wbInCriticalSection],0                    ;any task holding a critical section?
                        jne     irq0.30                                         ;yes, do not switch tasks
                        inc     byte [wbTaskIndex]                              ;increment task queue index (0-255)
                        movzx   eax,byte [wbTaskIndex]                          ;load task queue index
                        mov     dx,[wwTaskQueue+eax*2]                          ;next task selector
                        str     ax                                              ;current task selector
                        cmp     dx,ax                                           ;next task same is current task?
                        je      irq0.30                                         ;yes, skip task switch
;
;       Switch task
;
                        push    es                                              ;save extra segment register
                        push    EGDTALIAS                                         ;load GDT alias selector ...
                        pop     es                                              ;... into extra segment reg
                        and     byte [es:eax+5],0FDh                            ;reset task-busy bit of current task
                        pop     es                                              ;restore extra segment register
                        mov     word [wwFarJumpSelector],dx                     ;set next task selector in jmp instr
                        jmp     far [wdFarJumpEIP]                              ;jump to next task
;
;       Restore and return
;
irq0.30                 pop     ds                                              ;restore modified regs
                        pop     edx                                             ;
                        pop     eax                                             ;
                        iretd                                                   ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ1    Keyboard Interrupt
;
;       This handler is called when an IRQ1 hardware interrupt occurs, caused by a keyboard event. The scan-code(s)
;       corresponding to the keyboard event are read and message events are appended to the message queue. Since this
;       code is called in response to a hardware interrupt, no task switch occurs. We need to preseve the state of
;       ALL modified registers upon return. Note that keyboard messages are added to the keyboard focus message queue.
;       This is a queue referenced in the global descriptor table and must always reference the message queue for the
;       task that has the keyboard focus. To direct keyboard messages to another task, update the GDT descriptor to
;       point to the message queue for that task.
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  keyboard                                        ;keyboard interrrupt
                        push    eax                                             ;save non-volatile regs
                        push    ebx                                             ;
                        push    ecx                                             ;
                        push    esi                                             ;
                        push    ds                                              ;
                        push    EGDTOSDATA                                      ;load OS data selector ...
                        pop     ds                                              ;... into data segment register
                        xor     al,al                                           ;zero
                        mov     [wbConsoleScan0],al                             ;clear scan code 0
                        mov     [wbConsoleScan1],al                             ;clear scan code 1
                        mov     [wbConsoleScan2],al                             ;clear scan code 2
                        mov     [wbConsoleScan3],al                             ;clear scan code 3
                        mov     [wbConsoleScan4],al                             ;clear scan code 4
                        mov     [wbConsoleScan5],al                             ;clear scan code 5
                        mov     al,' '                                          ;space
                        mov     [wbConsoleChar],al                              ;set character to space
                        mov     al,EKEYFTIMEOUT                                 ;controller timeout flag
                        not     al                                              ;controller timeout mask
                        and     [wbConsoleStatus],al                            ;clear controller timeout flag
                        mov     bl,[wbConsoleShift]                             ;shift flags
                        mov     bh,[wbConsoleLock]                              ;lock flags
                        call    WaitForKeyOutBuffer                             ;controller timeout?
                        jz      irq1.140                                        ;yes, skip ahead
                        in      al,EKEYBPORTDATA                                ;read scan code 0
                        mov     [wbConsoleScan0],al                             ;save scan code 0
                        mov     ah,al                                           ;copy scan code 0
                        mov     al,EKEYFSHIFTLEFT                               ;left shift flag
                        cmp     ah,EKEYBSHIFTLDOWN                              ;left shift key down code?
                        je      irq1.30                                         ;yes, set flag
                        cmp     ah,EKEYBSHIFTLUP                                ;left shift key up code?
                        je      irq1.40                                         ;yes, reset flag
                        mov     al,EKEYFSHIFTRIGHT                              ;right shift flag
                        cmp     ah,EKEYBSHIFTRDOWN                              ;right shift key down code?
                        je      irq1.30                                         ;yes, set flag
                        cmp     ah,EKEYBSHIFTRUP                                ;right shift key up code?
                        je      irq1.40                                         ;yes, reset flag
                        mov     al,EKEYFCTRLLEFT                                ;left control flag
                        cmp     ah,EKEYBCTRLDOWN                                ;control key down code?
                        je      irq1.30                                         ;yes, set flag
                        cmp     ah,EKEYBCTRLUP                                  ;control key up code?
                        je      irq1.40                                         ;yes, reset flag
                        mov     al,EKEYFALTLEFT                                 ;left alt flag
                        cmp     ah,EKEYBALTDOWN                                 ;alt key down code?
                        je      irq1.30                                         ;yes, set flag
                        cmp     ah,EKEYBALTUP                                   ;alt key up code?
                        je      irq1.40                                         ;yes, reset flag
                        mov     al,EKEYFLOCKCAPS                                ;caps-lock flag
                        cmp     ah,EKEYBCAPSDOWN                                ;caps-lock key down code?
                        je      irq1.50                                         ;yes, toggle lamps and flags
                        mov     al,EKEYFLOCKNUM                                 ;num-lock flag
                        cmp     ah,EKEYBNUMDOWN                                 ;num-lock key down code?
                        je      irq1.50                                         ;yes, toggle lamps and flags
                        mov     al,EKEYFLOCKSCROLL                              ;scroll-lock flag
                        cmp     ah,EKEYBSCROLLDOWN                              ;scroll-lock key down code?
                        je      irq1.50                                         ;yes, toggle lamps and flags
                        cmp     ah,EKEYBCODEEXT0                                ;extended scan code 0?
                        jne     irq1.70                                         ;no, skip ahead
                        call    WaitForKeyOutBuffer                             ;controller timeout?
                        jz      irq1.140                                        ;yes, skip ahead
                        in      al,EKEYBPORTDATA                                ;read scan code 1
                        mov     [wbConsoleScan1],al                             ;save scan code 1
                        mov     ah,al                                           ;copy scan code 1
                        mov     al,EKEYFCTRLRIGHT                               ;right control flag
                        cmp     ah,EKEYBCTRLDOWN                                ;control key down code?
                        je      irq1.30                                         ;yes, set flag
                        cmp     ah,EKEYBCTRLUP                                  ;control key up code?
                        je      irq1.40                                         ;yes, reset flag
                        mov     al,EKEYFALTRIGHT                                ;right alt flag
                        cmp     ah,EKEYBALTDOWN                                 ;alt key down code?
                        je      irq1.30                                         ;yes, set flag
                        cmp     ah,EKEYBALTUP                                   ;alt key up code?
                        je      irq1.40                                         ;yes, reset flag
                        cmp     ah,EKEYBSLASH                                   ;slash down code?
                        je      irq1.80                                         ;yes, skip ahead
                        cmp     ah,EKEYBSLASHUP                                 ;slash up code?
                        je      irq1.80                                         ;yes, skip ahead
                        cmp     ah,EKEYBPRTSCRDOWN                              ;print screen down code?
                        je      irq1.10                                         ;yes, continue
                        cmp     ah,EKEYBPRTSCRUP                                ;print screen up code?
                        jne     irq1.20                                         ;no, skip ahead
irq1.10                 call    WaitForKeyOutBuffer                             ;controller timeout?
                        jz      irq1.140                                        ;yes, skip ahead
                        in      al,EKEYBPORTDATA                                ;read scan code 2
                        mov     [wbConsoleScan2],al                             ;save scan code 2
                        call    WaitForKeyOutBuffer                             ;controller timeout?
                        jz      irq1.140                                        ;yes, skip ahead
                        in      al,EKEYBPORTDATA                                ;read scan code 3
                        mov     [wbConsoleScan3],al                             ;read scan code 3
irq1.20                 jmp     irq1.150                                        ;finish keyboard handling
irq1.30                 or      bl,al                                           ;set shift flag
                        jmp     irq1.60                                         ;skip ahead
irq1.40                 not     al                                              ;convert flag to mask
                        and     bl,al                                           ;reset shift flag
                        jmp     irq1.60                                         ;skip ahead
irq1.50                 xor     bh,al                                           ;toggle lock flag
                        call    SetKeyboardLamps                                ;update keyboard lamps
irq1.60                 mov     [wbConsoleShift],bl                             ;save shift flags
                        mov     [wbConsoleLock],bh                              ;save lock flags
                        call    PutConsoleOIAShift                              ;update OIA indicators
                        jmp     irq1.150                                        ;finish keyboard handling
irq1.70                 cmp     ah,EKEYBCODEEXT1                                ;extended scan code 1?
                        jne     irq1.80                                         ;no continue
                        call    WaitForKeyOutBuffer                             ;controller timeout?
                        jz      irq1.140                                        ;yes, skip ahead
                        in      al,EKEYBPORTDATA                                ;read scan code 1
                        mov     [wbConsoleScan1],al                             ;save scan code 1
                        mov     ah,al                                           ;copy scan code 1
                        cmp     ah,EKEYBPAUSEDOWN                               ;pause key down code?
                        jne     irq1.150                                        ;no, finish keyboard handling
                        call    WaitForKeyOutBuffer                             ;controller timeout?
                        jz      irq1.140                                        ;yes, skip ahead
                        in      al,EKEYBPORTDATA                                ;read scan code 2
                        mov     [wbConsoleScan2],al                             ;save scan code 2
                        call    WaitForKeyOutBuffer                             ;controller timeout?
                        jz      irq1.140                                        ;yes, skip ahead
                        in      al,EKEYBPORTDATA                                ;read scan code 3
                        mov     [wbConsoleScan3],al                             ;save scan code 3
                        call    WaitForKeyOutBuffer                             ;controller timeout?
                        jz      irq1.140                                        ;yes, skip ahead
                        in      al,EKEYBPORTDATA                                ;read scan code 4
                        mov     [wbConsoleScan4],al                             ;save scan code 4
                        call    WaitForKeyOutBuffer                             ;controller timeout?
                        jz      irq1.140                                        ;yes, skip ahead
                        in      al,EKEYBPORTDATA                                ;read scan code 5
                        mov     [wbConsoleScan5],al                             ;save scan code 5
                        jmp     irq1.150                                        ;continue
irq1.80                 xor     al,al                                           ;assume no ASCII translation
                        test    ah,EKEYBUP                                      ;release code?
                        jnz     irq1.130                                        ;yes, skip ahead
                        mov     esi,tscan2ascii                                 ;scan-to-ascii table address
                        test    bl,EKEYFSHIFT                                   ;either shift key down?
                        jz      irq1.90                                         ;no, skip ahead
                        mov     esi,tscan2shift                                 ;scan-to-shifted table address
irq1.90                 movzx   ecx,ah                                          ;scan code offset
                        mov     al,[cs:ecx+esi]                                 ;al = ASCII code
                        test    bh,EKEYFLOCKCAPS                                ;caps-lock on?
                        jz      irq1.100                                        ;no skip ahead
                        mov     cl,al                                           ;copy ASCII code
                        and     cl,EASCIICASEMASK                               ;clear case mask of copy
                        cmp     cl,EASCIIUPPERA                                 ;less than 'A'?
                        jb      irq1.100                                        ;yes, skip ahead
                        cmp     cl,EASCIIUPPERZ                                 ;greater than 'Z'?
                        ja      irq1.100                                        ;yes, skip ahead
                        xor     al,EASCIICASE                                   ;switch case
irq1.100                mov     [wbConsoleChar],al                              ;save ASCII code
irq1.110                mov     edx,EMSGKEYDOWN                                 ;assume key-down event
                        test    ah,EKEYBUP                                      ;release scan-code?
                        jz      irq1.120                                        ;no, skip ahead
                        mov     edx,EMSGKEYUP                                   ;key-up event
irq1.120                and     eax,0FFFFh                                      ;clear high-order word
                        or      edx,eax                                         ;msg id and codes
                        xor     ecx,ecx                                         ;null param
                        push    eax                                             ;save codes
                        mov     eax,ESELKEYBOARDMQ                              ;keyboard focus message queue
                        call    PutMessage                                      ;put message to console
                        pop     eax                                             ;restore codes
                        test    al,al                                           ;ASCII translation?
                        jz      irq1.130                                        ;no, skip ahead
                        mov     edx,EMSGKEYCHAR                                 ;key-character event
                        and     eax,0FFFFh                                      ;clear high-order word
                        or      edx,eax                                         ;msg id and codes
                        xor     ecx,ecx                                         ;null param
                        mov     eax,ESELKEYBOARDMQ                              ;keyboard focus message queue
                        call    PutMessage                                      ;put message to console
irq1.130                jmp     irq1.150                                        ;finish keyboard handling
irq1.140                mov     al,EKEYFTIMEOUT                                 ;controller timeout flag
                        or      [wbConsoleStatus],al                            ;set controller timeout flag
irq1.150                call    PutConsoleOIAChar                               ;update operator info area
                        call    PutPrimaryEndOfInt                              ;send end-of-interrupt to PIC
                        pop     ds                                              ;restore non-volatile regs
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        pop     ebx                                             ;
                        pop     eax                                             ;
                        iretd                                                   ;return
;-----------------------------------------------------------------------------------------------------------------------
;       Scan-Code to ASCII Translation Tables
;-----------------------------------------------------------------------------------------------------------------------
tscan2ascii             db      000h,01Bh,031h,032h,033h,034h,035h,036h         ;00-07
                        db      037h,038h,039h,030h,02Dh,03Dh,008h,009h         ;08-0f
                        db      071h,077h,065h,072h,074h,079h,075h,069h         ;10-17
                        db      06Fh,070h,05Bh,05Dh,00Dh,000h,061h,073h         ;18-1f
                        db      064h,066h,067h,068h,06Ah,06Bh,06Ch,03Bh         ;20-27
                        db      027h,060h,000h,05Ch,07Ah,078h,063h,076h         ;28-2f
                        db      062h,06Eh,06Dh,02Ch,02Eh,02Fh,000h,02Ah         ;30-37
                        db      000h,020h,000h,000h,000h,000h,000h,000h         ;38-3f
                        db      000h,000h,000h,000h,000h,000h,000h,037h         ;40-47
                        db      038h,039h,02Dh,034h,035h,036h,02Bh,031h         ;48-4f
                        db      032h,033h,030h,02Eh,000h,000h,000h,000h         ;50-57
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;58-5f
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;60-67
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;68-6f
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;70-77
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;78-7f
tscan2shift             db      000h,01Bh,021h,040h,023h,024h,025h,05Eh         ;80-87
                        db      026h,02Ah,028h,029h,05Fh,02Bh,008h,000h         ;88-8f
                        db      051h,057h,045h,052h,054h,059h,055h,049h         ;90-97
                        db      04Fh,050h,07Bh,07Dh,00Dh,000h,041h,053h         ;98-9f
                        db      044h,046h,047h,048h,04Ah,04Bh,04Ch,03Ah         ;a0-a7
                        db      022h,07Eh,000h,07Ch,05Ah,058h,043h,056h         ;a8-af
                        db      042h,04Eh,04Dh,03Ch,03Eh,03Fh,000h,02Ah         ;b0-b7
                        db      000h,020h,000h,000h,000h,000h,000h,000h         ;b8-bf
                        db      000h,000h,000h,000h,000h,000h,000h,037h         ;c0-c7
                        db      038h,039h,02Dh,034h,035h,036h,02Bh,031h         ;c8-cf
                        db      032h,033h,030h,02Eh,000h,000h,000h,000h         ;d0-d7
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;d8-df
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;e0-e7
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;e8-ef
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;f0-f7
                        db      000h,000h,000h,000h,000h,000h,000h,000h         ;f8-ff
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ2    Secondary 8259A Cascade Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  iochannel                                       ;secondary 8259A cascade
                        push    eax                                             ;save modified regs
                        jmp     hwint                                           ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ3    Communication Port 2 Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  com2                                            ;serial port 2 interrupt
                        push    eax                                             ;save modified regs
                        jmp     hwint                                           ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ4    Communication Port 1 Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  com1                                            ;serial port 1 interrupt
                        push    eax                                             ;save modified regs
                        jmp     hwint                                           ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ5    Parallel Port 2 Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  lpt2                                            ;parallel port 2 interrupt
                        push    eax                                             ;save modified regs
                        jmp     hwint                                           ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ6    Diskette Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  diskette                                        ;floppy disk interrupt
                        push    eax                                             ;save non-volatile regs
                        push    ds                                              ;
                        push    EGDTOSDATA                                      ;load OS data selector ...
                        pop     ds                                              ;... into DS register
                        mov     al,[wbFDCStatus]                                ;AL = FDC calibration status
                        or      al,10000000b                                    ;set IRQ flag
                        mov     [wbFDCStatus],al                                ;update FDC calibration status
                        pop     ds                                              ;restore non-volatile regs
                        jmp     hwint                                           ;end primary PIC interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ7    Parallel Port 1 Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  lpt1                                            ;parallel port 1 interrupt
                        push    eax                                             ;save modified regs
                        jmp     hwint                                           ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ8    Real-time Clock Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  rtclock                                         ;real-time clock interrupt
                        push    eax                                             ;save modified regs
                        jmp     hwwint                                          ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ9    CGA Vertical Retrace Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  retrace                                         ;CGA vertical retrace interrupt
                        push    eax                                             ;save modified regs
                        jmp     hwwint                                          ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ10   Reserved Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  irq10                                           ;reserved
                        push    eax                                             ;save modified regs
                        jmp     hwwint                                          ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ11   Reserved Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  irq11                                           ;reserved
                        push    eax                                             ;save modified regs
                        jmp     hwwint                                          ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ12   PS/2 Mouse Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  ps2mouse                                        ;PS/2 mouse interrupt
                        push    eax                                             ;save modified regs
                        jmp     hwwint                                          ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ13   Coprocessor Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  coprocessor                                     ;coprocessor interrupt
                        push    eax                                             ;save modified regs
                        jmp     hwwint                                          ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ14   Fixed Disk Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  fixeddisk                                       ;fixed disk interrupt
                        push    eax                                             ;save modified regs
                        jmp     hwwint                                          ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       IRQ15   Reserved Hardware Interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  irq15                                           ;reserved
                        push    eax                                             ;save modified regs
                        jmp     hwwint                                          ;end interrupt and return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Exit from hardware interrupt
;
;-----------------------------------------------------------------------------------------------------------------------
hwwint                  call    PutSecondaryEndOfInt                            ;send EOI to secondary PIC
                        jmp     hwint90                                         ;skip ahead
hwint                   call    PutPrimaryEndOfInt                              ;send EOI to primary PIC
hwint90                 pop     eax                                             ;restore modified regs
                        iretd                                                   ;return from interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       INT 30h Operating System Software Service Interrupt
;
;       Interrupt 30h is used by our operating system as an entry point for many commonly-used subroutines reusable by
;       any task. These routines include low-level i/o functions that shield applications from having to handle
;       device-specific communications. On entry to this interrupt, AL contains a function number that is used to load
;       the entry address of the specific function from a table.
;
;-----------------------------------------------------------------------------------------------------------------------
                        menter  svc
                        cmp     al,maxtsvc                                      ;is our function out of range?
                        jae     svc90                                           ;yes, skip ahead
                        movzx   eax,al                                          ;function
                        shl     eax,2                                           ;offset into table
                        call    dword [cs:tsvc+eax]                             ;far call to indirect address
svc90                   iretd                                                   ;return from interrupt
;-----------------------------------------------------------------------------------------------------------------------
;
;       Service Request Table
;
;
;       These tsvce macros expand to define an address vector table for the service request interrupt (int 30h).
;
;-----------------------------------------------------------------------------------------------------------------------
tsvc                    tsvce   AllocateMemory                                  ;allocate memory block
                        tsvce   ClearConsoleScreen                              ;clear console screen
                        tsvce   CompareMemory                                   ;compare memory
                        tsvce   CopyMemory                                      ;copy memory
                        tsvce   DecimalToUnsigned                               ;convert decimal string to unsigned integer
                        tsvce   FreeMemory                                      ;free memory block
                        tsvce   GetBaseMemSize                                  ;get base RAM size in bytes
                        tsvce   GetConsoleString                                ;get string input
                        tsvce   GetExtendedMemSize                              ;get extended RAM size in bytes
                        tsvce   GetROMMemSize                                   ;get RAM size as reported by INT 12h
                        tsvce   HexadecimalToUnsigned                           ;convert hexadecimal string to unsigned integer
                        tsvce   IsLeapYear                                      ;return ecx=1 if leap year
                        tsvce   PlaceCursor                                     ;place the cursor at the current loc
                        tsvce   PutConsoleString                                ;tty output asciiz string
                        tsvce   PutDateString                                   ;put MM/DD/YYYY string
                        tsvce   PutDayString                                    ;put DD string
                        tsvce   PutHourString                                   ;put hh string
                        tsvce   PutMinuteString                                 ;put mm string
                        tsvce   PutMonthString                                  ;put MM string
                        tsvce   PutMonthNameString                              ;put name(MM) string
                        tsvce   PutSecondString                                 ;put ss string
                        tsvce   PutTimeString                                   ;put HH:MM:SS string
                        tsvce   PutWeekdayString                                ;put weekday string
                        tsvce   PutWeekdayNameString                            ;put name(weekday) string
                        tsvce   PutYearString                                   ;put YYYY string
                        tsvce   ReadRealTimeClock                               ;get real-time clock date and time
                        tsvce   ResetSystem                                     ;reset system using 8042 chip
                        tsvce   SetConsoleString                                ;set console string
                        tsvce   UnsignedToDecimalString                         ;convert unsigned integer to decimal string
                        tsvce   UnsignedToHexadecimal                           ;convert unsigned integer to hexadecimal string
                        tsvce   UpperCaseString                                 ;upper-case string
                        tsvce   Yield                                           ;halt until interrupt
maxtsvc                 equ     ($-tsvc)/4                                      ;function out of range
;-----------------------------------------------------------------------------------------------------------------------
;
;       Service Request Macros
;
;       These macros provide positional parameterization of service request calls.
;
;-----------------------------------------------------------------------------------------------------------------------
%macro                  allocateMemory 1
                        mov     ecx,%1                                          ;bytes to allocate
                        mov     al,eAllocateMemory                              ;allocate memory fn.
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  clearConsoleScreen 0
                        mov     al,eClearConsoleScreen                          ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  compareMemory 0
                        mov     al,eCompareMemory                               ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  decimalToUnsigned 0
                        mov     al,eDecimalToUnsigned                           ;function code
                        int     _svc                                            ;invoke OS servie
%endmacro
%macro                  compareMemory 3
                        mov     edx,%1                                          ;first memory address
                        mov     ebx,%2                                          ;second memory address
                        mov     ecx,%3                                          ;length
                        mov     al,eCompareMemory                               ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  copyMemory 3
                        mov     edx,%1                                          ;first memory address
                        mov     ebx,%2                                          ;second memory address
                        mov     ecx,%3                                          ;length
                        mov     al,eCopyMemory                                  ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  freeMemory 1
                        mov     edx,%1                                          ;address of memory block
                        mov     al,eFreeMemory                                  ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  getBaseMemSize 0
                        mov     al,eGetBaseMemSize                              ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  getConsoleString 4
                        mov     edx,%1                                          ;buffer address
                        mov     ecx,%2                                          ;max characters
                        mov     bh,%3                                           ;echo indicator
                        mov     bl,%4                                           ;terminator
                        mov     al,eGetConsoleString                            ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  getExtendedMemSize 0
                        mov     al,eGetExtendedMemSize                          ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  getROMMemSize 0
                        mov     al,eGetROMMemSize                               ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  hexadecimalToUnsigned 0
                        mov     al,eHexadecimalToUnsigned                       ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  isLeapYear 1
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     al,eIsLeapYear                                  ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  placeCursor 0
                        mov     al,ePlaceCursor                                 ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putConsoleString 1
                        mov     edx,%1                                          ;string address
                        mov     al,ePutConsoleString                            ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putDateString 0
                        mov     al,ePutDateString                               ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putDateString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutDateString                               ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putDayString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutDayString                                ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putHourString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutHourString                               ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putMinuteString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutMinuteString                             ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putMonthString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutMonthString                              ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putMonthNameString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutMonthNameString                          ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putSecondString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutSecondString                             ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putTimeString 0
                        mov     al,ePutTimeString                               ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putTimeString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutTimeString                               ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putWeekdayString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutWeekdayString                            ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putWeekdayNameString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutWeekdayNameString                        ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  putYearString 2
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     edx,%2                                          ;output buffer addr
                        mov     al,ePutYearString                               ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  readRealTimeClock 0
                        mov     al,eReadRealTimeClock                           ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  readRealTimeClock 1
                        mov     ebx,%1                                          ;DATETIME addr
                        mov     al,eReadRealTimeClock                           ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  resetSystem 0
                        mov     al,eResetSystem                                 ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  setConsoleString 0
                        mov     al,eSetConsoleString                            ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  unsignedToDecimalString 0
                        mov     al,eUnsignedToDecimalString                     ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  unsignedToHexadecimal 0
                        mov     al,eUnsignedToHexadecimal                       ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  upperCaseString 0
                        mov     al,eUpperCaseString                             ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
%macro                  yield 0
                        mov     al,eYield                                       ;function code
                        int     _svc                                            ;invoke OS service
%endmacro
;=======================================================================================================================
;
;       Kernel Function Library
;
;=======================================================================================================================
;=======================================================================================================================
;
;       Date and Time Helper Routines
;
;       GetYear
;       IsLeapYear
;       PutDateString
;       PutDayString
;       PutHourString
;       PutMinuteString
;       PutMonthString
;       PutMonthNameString
;       PutSecondString
;       PutTimeString
;       PutWeekdayString
;       PutWeekdayNameString
;       PutYearString
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        GetYear
;
;       Description:    Return the four-digit year (century * 100 + year of century)
;
;       In:             DS:EBX  DATETIME address
;
;       Out:            ECX     year
;
;-----------------------------------------------------------------------------------------------------------------------
GetYear                 movzx   ecx,byte [ebx+DATETIME.century]                 ;century
                        imul    ecx,100                                         ;century * 100
                        movzx   eax,byte [ebx+DATETIME.year]                    ;year of century
                        add     ecx,eax                                         ;year (YYYY)
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        IsLeapYear
;
;       Description:    This routine returns an indicator if the current year is a leap year.
;
;       In:             DS:EBX  DATETIME ADDRESS
;
;       Out:            ECX     0 = not a leap year
;                               1 = leap year
;
;-----------------------------------------------------------------------------------------------------------------------
IsLeapYear              call    GetYear                                         ;ECX = YYYY
                        mov     eax,ecx                                         ;EAX = YYYY
                        xor     ecx,ecx                                         ;assume not leap year
                        test    al,00000011b                                    ;multiple of four?
                        jnz     .no                                             ;no, branch
                        mov     dl,100                                          ;divisor
                        div     dl                                              ;divide by 100
                        test    ah,ah                                           ;multiple of 100?
                        jnz     .yes                                            ;yes, branch
                        test    al,00000011b                                    ;multiple of 400?
                        jnz     .no                                             ;no, branch
.yes                    inc     ecx                                             ;indicate leap
.no                     ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutDateString
;
;       Description:    This routine returns an ASCIIZ mm/dd/yyyy string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutDateString           push    ecx                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    es                                              ;
                        push    ds                                              ;store data selector ...
                        pop     es                                              ;... in extra segment reg
                        mov     edi,edx                                         ;output buffer address
                        mov     cl,10                                           ;divisor
                        mov     edx,0002F3030h                                  ;ASCIIZ "00/" (reversed)
                        movzx   eax,byte [ebx+DATETIME.month]                   ;month
                        div     cl                                              ;AH = rem; AL = quotient
                        or      eax,edx                                         ;apply ASCII zones and delimiter
                        cld                                                     ;forward strings
                        stosd                                                   ;store "mm/"nul
                        dec     edi                                             ;address of terminator
                        movzx   eax,byte [ebx+DATETIME.day]                     ;day
                        div     cl                                              ;AH = rem; AL = quotient
                        or      eax,edx                                         ;apply ASCII zones and delimiter
                        stosd                                                   ;store "dd/"nul
                        dec     edi                                             ;address of terminator
                        movzx   eax,byte [ebx+DATETIME.century]                 ;century
                        div     cl                                              ;AH = rem; AL = quotient
                        or      eax,edx                                         ;apply ASCII zones and delimiter
                        stosd                                                   ;store "cc/"null
                        dec     edi                                             ;address of terminator
                        dec     edi                                             ;address of delimiter
                        movzx   eax,byte [ebx+DATETIME.year]                    ;year (yy)
                        div     cl                                              ;AH = rem; AL = quotient
                        or      eax,edx                                         ;apply ASCII zones and delimiter
                        stosb                                                   ;store quotient
                        mov     al,ah                                           ;remainder
                        stosb                                                   ;store remainder
                        xor     al,al                                           ;null terminator
                        stosb                                                   ;store terminator
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutDayString
;
;       Description:    This routine returns an ASCIIZ dd string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutDayString            push    ecx                                             ;save non-volatile regs
                        movzx   ecx,byte [ebx+DATETIME.day]                     ;day
                        mov     bh,1                                            ;trim leading zeros; no commas
                        call    UnsignedToDecimalString                         ;store ASCII decimal string
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutHourString
;
;       Description:    This routine returns an ASCIIZ hh string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutHourString           push    ecx                                             ;save non-volatile regs
                        movzx   ecx,byte [ebx+DATETIME.hour]                    ;hour
                        mov     bh,1                                            ;trim leading zeros; no commas
                        call    UnsignedToDecimalString                         ;store ASCII decimal string
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutMinuteString
;
;       Description:    This routine returns an ASCIIZ mm string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutMinuteString         push    ecx                                             ;save non-volatile regs
                        movzx   ecx,byte [ebx+DATETIME.minute]                  ;minute
                        mov     bh,1                                            ;trim leading zeros; no commas
                        call    UnsignedToDecimalString                         ;store ASCII decimal string
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutMonthString
;
;       Description:    This routine returns an ASCIIZ mm string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutMonthString          push    ecx                                             ;save non-volatile regs
                        movzx   ecx,byte [ebx+DATETIME.month]                   ;month
                        mov     bh,1                                            ;trim leading zeros; no commas
                        call    UnsignedToDecimalString                         ;store ASCII decimal string
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutMonthNameString
;
;       Description:    This routine returns an ASCIIZ name(mm) string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutMonthNameString      push    esi                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    ds                                              ;
                        push    es                                              ;
                        push    ds                                              ;load data selector ...
                        pop     es                                              ;... into extra segment
                        mov     edi,edx                                         ;output buffer address
                        movzx   eax,byte [ebx+DATETIME.month]                   ;month (1-12)
                        dec     eax                                             ;month (0-11)
                        shl     eax,2                                           ;offset into month name lookup table
                        push    cs                                              ;load code selector ...
                        pop     ds                                              ;... into data segment
                        mov     esi,[tMonthNames+eax]                           ;month name address
                        cld                                                     ;forward strings
.10                     lodsb                                                   ;name character
                        stosb                                                   ;store in output buffer
                        test    al,al                                           ;end of string?
                        jnz     .10                                             ;no, continue
                        pop     es                                              ;restore non-volatile regs
                        pop     ds                                              ;
                        pop     edi                                             ;
                        pop     esi                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutSecondString
;
;       Description:    This routine returns an ASCIIZ ss string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutSecondString         push    ecx                                             ;save non-volatile regs
                        movzx   ecx,byte [ebx+DATETIME.second]                  ;second
                        mov     bh,1                                            ;trim leading zeros; no commas
                        call    UnsignedToDecimalString                         ;store ASCII decimal string
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutTimeString
;
;       Description:    This routine returns an ASCIIZ hh:mm:ss string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutTimeString           push    ecx                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    es                                              ;
                        push    ds                                              ;store data selector ...
                        pop     es                                              ;... in extra segment reg
                        mov     edi,edx                                         ;output buffer address
                        mov     cl,10                                           ;divisor
                        mov     edx,003a3030h                                   ;ASCIIZ "00:" (reversed)
                        movzx   eax,byte [ebx+DATETIME.hour]                    ;hour
                        div     cl                                              ;ah = rem; al = quotient
                        or      eax,edx                                         ;apply ASCII zones and delimiter
                        cld                                                     ;forward strings
                        stosd                                                   ;store "mm/"nul
                        dec     edi                                             ;address of terminator
                        movzx   eax,byte [ebx+DATETIME.minute]                  ;minute
                        div     cl                                              ;ah = rem; al = quotient
                        or      eax,edx                                         ;apply ASCII zones and delimiter
                        stosd                                                   ;store "dd/"nul
                        dec     edi                                             ;address of terminator
                        movzx   eax,byte [ebx+DATETIME.second]                  ;second
                        div     cl                                              ;ah = rem; al = quotient
                        or      eax,edx                                         ;apply ASCII zones and delimiter
                        stosb                                                   ;store quotient
                        mov     al,ah                                           ;remainder
                        stosb                                                   ;store remainder
                        xor     al,al                                           ;null terminator
                        stosb                                                   ;store terminator
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutWeekdayString
;
;       Description:    This routine returns an ASCIIZ weekday string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutWeekdayString        push    ecx                                             ;save non-volatile regs
                        movzx   ecx,byte [ebx+DATETIME.weekday]                 ;weekday
                        mov     bh,1                                            ;trim leading zeros; no commas
                        call    UnsignedToDecimalString                         ;store ASCII decimal string
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutWeekdayNameString
;
;       Description:    This routine returns an ASCIIZ name(weekday) string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutWeekdayNameString    push    esi                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    ds                                              ;
                        push    es                                              ;
                        push    ds                                              ;load data selector ...
                        pop     es                                              ;... into extra segment
                        mov     edi,edx                                         ;output buffer address
                        movzx   eax,byte [ebx+DATETIME.weekday]                 ;weekday (0-6)
                        shl     eax,2                                           ;offset into day name lookup table
                        push    cs                                              ;load code selector ...
                        pop     ds                                              ;... into data segment
                        mov     esi,[tDayNames+eax]                             ;day name address
                        cld                                                     ;forward strings
.10                     lodsb                                                   ;name character
                        stosb                                                   ;store in output buffer
                        test    al,al                                           ;end of string?
                        jnz     .10                                             ;no, continue
                        pop     es                                              ;restore non-volatile regs
                        pop     ds                                              ;
                        pop     edi                                             ;
                        pop     esi                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutYearString
;
;       Description:    This routine returns an ASCIIZ yyyy string at ds:edx from the date in the DATETIME
;                       structure at ds:ebx.
;
;       In:             DS:EBX  DATETIME address
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
PutYearString           push    ecx                                             ;save non-volatile regs
                        call    GetYear                                         ;ECX = YYYY
                        mov     bh,1                                            ;trim leading zeros; no commas
                        call    UnsignedToDecimalString                         ;store decimal string at DS:EDX
                        pop     ecx                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Day Names
;
;-----------------------------------------------------------------------------------------------------------------------
czSunday                db      "Sunday",0
czMonday                db      "Monday",0
czTuesday               db      "Tuesday",0
czWednesday             db      "Wednesday",0
czThursday              db      "Thursday",0
czFriday                db      "Friday",0
czSaturday              db      "Saturday",0
;-----------------------------------------------------------------------------------------------------------------------
;
;       Month Names
;
;-----------------------------------------------------------------------------------------------------------------------
czJanuary               db      "January",0
czFebruary              db      "February",0
czMarch                 db      "March",0
czApril                 db      "April",0
czMay                   db      "May",0
czJune                  db      "June",0
czJuly                  db      "July",0
czAugust                db      "August",0
czSeptember             db      "September",0
czOctober               db      "October",0
czNovember              db      "November",0
czDecember              db      "December",0
;-----------------------------------------------------------------------------------------------------------------------
;
;       Day Names Lookup Table
;
;-----------------------------------------------------------------------------------------------------------------------
                        align   4
tDayNames               equ     $
                        dd      czSunday
                        dd      czMonday
                        dd      czTuesday
                        dd      czWednesday
                        dd      czThursday
                        dd      czFriday
                        dd      czSaturday
EDAYNAMESTBLL           equ     ($-tDayNames)
EDAYNAMESTBLCNT         equ     EDAYNAMESTBLL/4
;-----------------------------------------------------------------------------------------------------------------------
;
;       Month Names Lookup Table
;
;-----------------------------------------------------------------------------------------------------------------------
                        align   4
tMonthNames             equ     $
                        dd      czJanuary
                        dd      czFebruary
                        dd      czMarch
                        dd      czApril
                        dd      czMay
                        dd      czJune
                        dd      czJuly
                        dd      czAugust
                        dd      czSeptember
                        dd      czOctober
                        dd      czNovember
                        dd      czDecember
EMONTHNAMESTBLL         equ     ($-tMonthNames)
EMONTHNAMESTBLCNT       equ     EMONTHNAMESTBLL/4
;=======================================================================================================================
;
;       Memory Helper Routines
;
;       AllocateMemory
;       FreeMemory
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        AllocateMemory
;
;       Description:    This routine allocates a memory block for the given task.
;
;       In:             ECX     bytes of memory to allocate
;
;       Out:            EAX     !0      address of user portion of newly allocated memory block
;                               0       unable to allocate memory
;
;-----------------------------------------------------------------------------------------------------------------------
AllocateMemory          push    ebx                                             ;save non-volatile regs
                        push    ecx                                             ;
                        push    esi                                             ;
                        push    ds                                              ;
;
;       Address kernel memory structures
;
                        push    EGDTOSDATA                                      ;load OS data GDT selector ...
                        pop     ds                                              ;... into data segment reg
                        mov     esi,wsConsoleMemRoot                            ;memory root structure address
;
;       Set requested size to minimum block size if requested size is too small.
;
                        cmp     ecx,EMEMMINSIZE                                 ;is requested size too small?
                        jae     .10                                             ;no, branch
                        mov     ecx,EMEMMINSIZE                                 ;set requested size to minimum
.10                     add     ecx,EMEMBLOCKLEN                                ;add header block length
;
;       Find the first free memory block large enough to satisfy the request.
;
                        mov     eax,[esi+MEMROOT.firstfree]                     ;first free block ptr
.20                     test    eax,eax                                         ;end of free block chain?
                        jz      .220                                            ;yes, branch
                        cmp     ecx,[eax+MEMBLOCK.bytes]                        ;free block big enough?
                        jbe     .30                                             ;yes, branch
                        mov     eax,[eax+MEMBLOCK.nextblock]                    ;next free block addr
                        jmp     .20                                             ;continue
;-----------------------------------------------------------------------------------------------------------------------
;
;       Address the previous and next free memory blocks.
;
.30                     mov     ebx,[eax+MEMBLOCK.previousblock]                ;previous free block addr
                        mov     edx,[eax+MEMBLOCK.nextblock]                    ;next free block addr
;
;       Remove the free memory block from the forward free memory block chain.
;
                        test    ebx,ebx                                         ;any previous free memory block?
                        jz      .40                                             ;no, branch
                        mov     [ebx+MEMBLOCK.nextblock],edx                    ;remove free block from forwrad chain
                        jmp     .50                                             ;continue
.40                     mov     [esi+MEMROOT.firstfree],edx                     ;next free is now also the first free
;
;       Remove the free memory block from the reverse free memory block chain.
;
.50                     test    edx,edx                                         ;any next free memory block?
                        jz      .60                                             ;no, branch
                        mov     [edx+MEMBLOCK.previousblock],ebx                ;remove free block from reverse chain
                        jmp     .70                                             ;continue
.60                     mov     [esi+MEMROOT.lastfree],ebx                      ;previous free is now also the last free
;-----------------------------------------------------------------------------------------------------------------------
;
;       Determine if the free memory block can be split.
;
.70                     mov     ebx,[eax+MEMBLOCK.bytes]                        ;size of free memory block
                        sub     ebx,ecx                                         ;subtract requested memory size
                        cmp     ebx,EMEMMINSIZE                                 ;remaining block can stand alone?
                        jb      .150                                            ;no, branch
;
;       We know that our block can be split to create a new free memory block. We update the size of our free memory
;       block to the requested memory size. We update the next contiguous block pointer to point just past the end
;       of the requested memory size.
;
                        mov     [eax+MEMBLOCK.bytes],ecx                        ;shorten memory block size
                        mov     edx,eax                                         ;memory block address
                        add     edx,ecx                                         ;address new new next contig block
                        mov     ecx,[eax+MEMBLOCK.nextcontig]                   ;next contig block address
                        mov     [eax+MEMBLOCK.nextcontig],edx                   ;update next contig block address
;
;       If there is a next contiguous block, we update that memory block's previous contig pointer to point to the new
;       free block we are splitting off. If there is no next contiguous block, we update the last contig block pointer.
;
                        jecxz   .80                                             ;no next contig, branch
                        mov     [ecx+MEMBLOCK.previouscontig],edx               ;update previous contig pointer
                        jmp     .90                                             ;continue
.80                     mov     [esi+MEMROOT.lastcontig],edx                    ;update last contig pointer
;
;       Now that the contig block pointers have been updated, we initialize the new free block members.
;
.90                     mov     [edx+MEMBLOCK.bytes],ebx                        ;set the block size
                        mov     [edx+MEMBLOCK.nextcontig],ecx                   ;set the next contig block addr
                        mov     [edx+MEMBLOCK.previouscontig],eax               ;set the previous contig block addr
                        mov     ebx,EMEMFREECODE                                ;free memory signature
                        mov     [edx+MEMBLOCK.signature],ebx                    ;set the block signature
                        xor     ebx,ebx                                         ;zero register
                        mov     [edx+MEMBLOCK.reserved],ebx                     ;set reserved
                        mov     [edx+MEMBLOCK.owner],ebx                        ;set the owner
;
;       Find the proper location in the free block chain for the new free block
;
                        mov     ebx,[edx+MEMBLOCK.bytes]                        ;free block size
                        mov     ecx,[esi+MEMROOT.firstfree]                     ;first free block addr
.100                    jecxz   .110                                            ;branch if at end of chain
                        cmp     ebx,[ecx+MEMBLOCK.bytes]                        ;new block smaller or equal?
                        jbe     .110                                            ;yes, branch
                        mov     ecx,[ecx+MEMBLOCK.nextblock]                    ;next free block addr
                        jmp     .100                                            ;continue
;
;       Having found the proper location for our new free block, we store the address of the following free block, or
;       zero if our new free block is larger than any other, as our next free block. Then, we take the address of our
;       next block's previous block or the global last-free block as our new previous block and update the previous
;       block of hte next block, if there is one.
;
.110                    mov     [edx+MEMBLOCK.nextblock],ecx                    ;set the new free block's next ptr
                        mov     ebx,[esi+MEMROOT.lastfree]                      ;last free block addr
                        jecxz   .120                                            ;branch if no next block
                        mov     ebx,[ecx+MEMBLOCK.previousblock]                ;next block's previous block
                        mov     [ecx+MEMBLOCK.previousblock],edx                ;set the next block's previous block
                        jmp     .130                                            ;continue
.120                    mov     [esi+MEMROOT.lastfree],edx                      ;set the new last free block
;
;       Store our previous block pointer. If we have a previous free block, update that block's next block pointer to
;       point to the new block. Since the new block may now be the first or last user block, we update the first and/or
;       last user block pointers if necessary.
;
.130                    mov     [edx+MEMBLOCK.previousblock],ebx                ;set the previous block pointer
                        test    ebx,ebx                                         ;is there a previous block?
                        jz      .140                                            ;no, branch
                        mov     [ebx+MEMBLOCK.nextblock],edx                    ;set the previous block's next ptr
                        jmp     .150                                            ;continue
.140                    mov     [esi+MEMROOT.firstfree],edx                     ;set the new first free ptr
;
;       Update the newly allocated block's owner and signature.
;
.150                    mov     edx,EMEMUSERCODE                                ;user memory signature
                        mov     [eax+MEMBLOCK.signature],edx                    ;set the block signature
                        xor     edx,edx                                         ;zero register
                        str     dx                                              ;load the task state register
                        mov     [eax+MEMBLOCK.owner],edx                        ;set the block owner
;
;       Remove the allocated block from the free block chain and insert it into the user block chain.
;
                        mov     ecx,[esi+MEMROOT.firsttask]                     ;first task block
.160                    jecxz   .180                                            ;branch if at end of chain
                        cmp     edx,[ecx+MEMBLOCK.owner]                        ;does this block belong to the task?
                        jb      .180                                            ;branch if block belongs to next task
                        je      .170                                            ;branch if block belongs to this task
                        mov     ecx,[ecx+MEMBLOCK.nextblock]                    ;next task block
                        jmp     .160                                            ;continue
;
;       We have found the start of our task's user block chain or the start of the next task's user block chain. If we
;       have found the next task's chain, then we have no other user memory for this task and we can simply add the
;       block here. If we are at the start of our task's user block chain, then we need to further seek for the proper
;       place to insert the block.
;
.170                    mov     edx,[eax+MEMBLOCK.bytes]                        ;size of block in bytes
                        cmp     edx,[ecx+MEMBLOCK.bytes]                        ;less or equal to chain block?
                        jbe     .180                                            ;yes, branch
                        mov     ecx,[ecx+MEMBLOCK.nextblock]                    ;next chain block address
                        test    ecx,ecx                                         ;end of chain?
                        jz      .180                                            ;yes, branch
                        mov     edx,[eax+MEMBLOCK.owner]                        ;owning task
                        cmp     edx,[ecx+MEMBLOCK.owner]                        ;same task?
                        je      .170                                            ;yes, continue search
;
;       We have found the proper place in our task's user-block chain to insert our new user block. It may also be the
;       end of the user-block chain. To insert our new user block, first we update the next-block pointer. Then, we load
;       the next-block's previous-block pointer or the global last-user block pointer if we have no next-block. If we
;       do have a previous-block, we update that block's next-block pointer.
;
.180                    mov     [eax+MEMBLOCK.nextblock],ecx                    ;set the next task block
                        mov     ebx,[esi+MEMROOT.lasttask]                      ;last task block
                        jecxz   .190                                            ;branch if no next-task block
                        mov     ebx,[ecx+MEMBLOCK.previousblock]                ;next-task's previous-task block
                        mov     [ecx+MEMBLOCK.previousblock],eax                ;update next-task block's previous-task
                        jmp     .200                                            ;continue
.190                    mov     [esi+MEMROOT.lasttask],eax                      ;new block is the last user-block
;
;       Now wes tore our previous-block pointer and, if we have a previous-free block, we update that block's next-
;       block pointer to point to our block. Since our block may now be the first or last user-block, we update the
;       global first and/or last user-block pointers if necessary.
;
.200                    mov     [eax+MEMBLOCK.previousblock],ebx                ;set the previous task block
                        test    ebx,ebx                                         ;do we have a previous task block?
                        jz      .210                                            ;no, branch
                        mov     [ebx+MEMBLOCK.nextblock],eax                    ;set previous-block's next-task block
                        jmp     .220                                            ;continue
.210                    mov     [esi+MEMROOT.firsttask],eax                     ;new block is the first user-block
;
;       Restore registers and return to caller.
;
.220                    pop     ds                                              ;restore non-volatie regs
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        pop     ebx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        FreeMemory
;
;       Description:    This routine frees a memory block for the given task. The address provided in EDX points to the
;                       memory block header. The memory block must be USER memory, not a FREE memory block. If the block
;                       is adjacent to a contiguous FREE memory block, then the blocks are merged. The residual FREE
;                       memory is repositioned in the FREE memory block chain according to size. The user portion of the
;                       block, following the block header, is reset (wiped) with the memory wipe value.
;
;       In:             EDX     memory block to free, relative to EGDTOSDATA
;
;       Out:            EAX     -1      invalid memory block
;                               0       memory block freed
;
;-----------------------------------------------------------------------------------------------------------------------
FreeMemory              push    ebx                                             ;save non-volatile regs
                        push    ecx                                             ;
                        push    esi                                             ;
                        push    edi                                             ;
                        push    ds                                              ;
                        push    es                                              ;
;
;       Address the root memory structure
;
                        push    EGDTOSDATA                                      ;load OS data selector ...
                        pop     es                                              ;... into extra segment reg
                        push    EGDTOSDATA                                      ;load OS data selector ...
                        pop     ds                                              ;... into data segment reg
                        mov     esi,wsConsoleMemRoot                            ;memory root structure
                        mov     edi,edx                                         ;memory block address
;
;       If the block is FREE, return success. Otherwise, if it is not USER, return with error.
;
                        xor     eax,eax                                         ;indicate success
                        cmp     dword [edi+MEMBLOCK.signature],EMEMFREECODE     ;is the block FREE?
                        je      .240                                            ;yes, branch
                        dec     eax                                             ;indicate failure
                        cmp     dword [edi+MEMBLOCK.signature],EMEMUSERCODE     ;is the block USER?
                        jne     .240                                            ;no, branch
;-----------------------------------------------------------------------------------------------------------------------
;
;       Unlink the USER memory block.
;
;-----------------------------------------------------------------------------------------------------------------------
;
;       Set the block signature. Reset owner.
;
                        mov     dword [edi+MEMBLOCK.signature],EMEMFREECODE     ;set FREE block signature
                        xor     eax,eax                                         ;zero register
                        mov     [edi+MEMBLOCK.owner],eax                        ;zero block owner
;
;       Wipe user area.
;
                        push    edi                                             ;save block address
                        mov     ecx,[edi+MEMBLOCK.bytes]                        ;block size
                        sub     ecx,EMEMBLOCKLEN                                ;subtract header size
                        add     edi,EMEMBLOCKLEN                                ;point to user area
                        mov     al,EMEMWIPEBYTE                                 ;memory wipe byte
                        rep     stosb                                           ;clear memory
                        pop     edi                                             ;restore block address
;
;       Address the preceding and following USER memory blocks
;
                        mov     ebx,[edi+MEMBLOCK.previousblock]                ;previous block pointer
                        mov     ecx,[edi+MEMBLOCK.nextblock]                    ;next block pointer
;
;       If a USER block precedes this block, update that block's next pointer. Otherwise, update the first task
;       pointer to point to the USER block following this block.
;
                        test    ebx,ebx                                         ;is there a previous block?
                        jz      .10                                             ;no, branch
                        mov     [ebx+MEMBLOCK.nextblock],ecx                    ;update previous block's next pointer
                        jmp     .20                                             ;continue
.10                     mov     [esi+MEMROOT.firsttask],ecx                     ;update first USER pointer
;
;       If a USER block follows this block, update that block's previous pointer. Otherwise, update the last task
;       pointer to point to the USER block preceding this block.
;
.20                     jecxz   .30                                             ;branch if no next block
                        mov     [ecx+MEMBLOCK.previousblock],ebx                ;update next block's previous pointer
                        jmp     .40                                             ;continue
.30                     mov     [esi+MEMROOT.lasttask],ebx                      ;update last USER pointer
;-----------------------------------------------------------------------------------------------------------------------
;
;       Merge with a previous contiguous FREE memory block.
;
;-----------------------------------------------------------------------------------------------------------------------
;
;       Address the preceding and following contiguous memory blocks.
;
.40                     mov     ebx,[edi+MEMBLOCK.previouscontig]               ;previous contiguous block ptr
                        mov     ecx,[edi+MEMBLOCK.nextcontig]                   ;next contiguous block ptr
;
;       Verify we have a previous contiguous FREE block.
;
                        test    ebx,ebx                                         ;is there a previous block?
                        jz      .100                                            ;no, branch
                        cmp     dword [ebx+MEMBLOCK.signature],EMEMFREECODE     ;is the previous block FREE?
                        jne     .100                                            ;no, branch
;
;       Update adjacent block's contiguous pointers.
;
                        mov     [ebx+MEMBLOCK.nextcontig],ecx                   ;update previous contig's next contig
                        jecxz   .50                                             ;branch if no next contiguous block
                        mov     [ecx+MEMBLOCK.previouscontig],ebx               ;update next congit's previous contig
                        jmp     .60                                             ;continue
.50                     mov     [esi+MEMROOT.lastcontig],ebx                    ;update last contig pointer
;
;       Update the size of the merged FREE block.
;
.60                     mov     eax,[edi+MEMBLOCK.bytes]                        ;current block size
                        add     [ebx+MEMBLOCK.bytes],eax                        ;update previous block's size
;
;       Having merged our new free block into the previous free block, make the previous free block the current block
;
                        mov     ecx,EMEMBLOCKLEN                                ;block header length
                        mov     al,EMEMWIPEBYTE                                 ;memory wipe byte
                        rep     stosb                                           ;clear memory header
                        mov     edi,ebx                                         ;current block is now previous block
;-----------------------------------------------------------------------------------------------------------------------
;
;       Unlink the previous contiguous FREE memory block
;
;-----------------------------------------------------------------------------------------------------------------------
;
;       Address the preceding and following USER memory blocks
;
                        mov     ebx,[edi+MEMBLOCK.previousblock]                ;previous block pointer
                        mov     ecx,[edi+MEMBLOCK.nextblock]                    ;next block pointer
;
;       Update the previous block's next-block pointer if there is a previous block. Otherwise, update the first free
;       block pointer.
;
                        test    ebx,ebx                                         ;is there a previous block?
                        jz      .70                                             ;no, branch
                        mov     [ebx+MEMBLOCK.nextblock],ecx                    ;update previous block's next pointer
                        jmp     .80                                             ;branch
.70                     mov     [esi+MEMROOT.firstfree],ecx                     ;update first FREE block pointer
;
;       Update the next block's previous-block pointer if there is a next block. Otherwise, update the last free block
;       pointer.
;
.80                     jecxz   .90                                             ;branch if no next block
                        mov     [ecx+MEMBLOCK.previousblock],ebx                ;update next block's previous pointer
                        jmp     .100                                            ;continue
.90                     mov     [esi+MEMROOT.lastfree],ebx                      ;update last FREE block pointer
;-----------------------------------------------------------------------------------------------------------------------
;
;       Merge with a following contiguous FREE memory block.
;
;-----------------------------------------------------------------------------------------------------------------------
;
;       Verify we have a following contiguous FREE block.
;
.100                    mov     ecx,[edi+MEMBLOCK.nextcontig]                   ;next contiguous block ptr
                        jecxz   .170                                            ;branch if no next contiguous block
                        cmp     dword [ecx+MEMBLOCK.signature],EMEMFREECODE     ;is the next-contiguous block free?
                        jne     .170                                            ;no, branch
;
;       Add the size of the following adjacent FREE block to this block's size.
;
                        mov     eax,[ecx+MEMBLOCK.bytes]                        ;next contiguous (free) block size
                        add     [edi+MEMBLOCK.bytes],eax                        ;add size to this block's size
;
;       Unlink the following contiguous FREE block from the contiguous block chain.
;
                        mov     eax,[ecx+MEMBLOCK.nextcontig]                   ;following block's next-contig ptr
                        mov     [edi+MEMBLOCK.nextcontig],eax                   ;update this block's next-contig ptr
                        test    eax,eax                                         ;does a block follow the next contig blk
                        jz      .110                                            ;no, branch
                        mov     [eax+MEMBLOCK.previouscontig],edi               ;update following block's prev contig
                        jmp     .120                                            ;continue
.110                    mov     [esi+MEMROOT.lastcontig],edi                    ;update last contig block ptr
;-----------------------------------------------------------------------------------------------------------------------
;
;       Unlink the following contiguous FREE memory block
;
;-----------------------------------------------------------------------------------------------------------------------
;
;       Unlink the following adjacent FREE block from the FREE block chain.
;
.120                    push    edi                                             ;save this block
                        mov     edi,ecx                                         ;next contiguous block
                        push    ecx                                             ;save next contiguous block
;
;       Address the preceding and following USER memory blocks
;
                        mov     ebx,[edi+MEMBLOCK.previousblock]                ;next contig's previous block pointer
                        mov     ecx,[edi+MEMBLOCK.nextblock]                    ;next contig's next block pointer
;
;       Update the previous block's next-block pointer if there is a previous block. Otherwise, update the first free
;       block pointer.
;
                        test    ebx,ebx                                         ;is there a previous block?
                        jz      .130                                            ;no, branch
                        mov     [ebx+MEMBLOCK.nextblock],ecx                    ;update next contig's prev blk next-ptr
                        jmp     .140                                            ;branch
.130                    mov     [esi+MEMROOT.firstfree],ecx                     ;update first FREE block pointer
;
;       Update the next block's previous-block pointer if there is a next block. Otherwise, update the last free block
;       pointer.
;
.140                    jecxz   .150                                            ;branch if no next block
                        mov     [ecx+MEMBLOCK.previousblock],ebx                ;update next contig's next blk prev-ptr
                        jmp     .160                                            ;continue
.150                    mov     [esi+MEMROOT.lastfree],ebx                      ;update last FREE block pointer
;
;       Clear next contiguous block's header
;
.160                    pop     edi                                             ;next congiguous block pointer
                        mov     ecx,EMEMBLOCKLEN                                ;memory block header length
                        mov     al,EMEMWIPEBYTE                                 ;memory wipe byte
                        rep     stosb                                           ;clear memory header
                        pop     edi                                             ;this block's pointer
;-----------------------------------------------------------------------------------------------------------------------
;
;       Insert the final FREE block back into the block chain.
;
;-----------------------------------------------------------------------------------------------------------------------
;
;       Walk the FREE memory chain until a block is found that is larger than or equal in size to the block being
;       inserted. The block being inserted will be inserted before that block or after the last block found if none
;       all are smaller in size.
;
.170                    mov     ebx,[edi+MEMBLOCK.bytes]                        ;size of block
                        mov     ecx,[esi+MEMROOT.firstfree]                     ;first free block ptr
.180                    jecxz   .190                                            ;exit if no ptr
                        cmp     ebx,[ecx+MEMBLOCK.bytes]                        ;next block bigger?
                        jb      .190                                            ;yes, branch
                        mov     ecx,[ecx+MEMBLOCK.nextblock]                    ;next free memory block
                        jmp     .180                                            ;continue
;
;       Set the next-block pointer. Determine the previous-block, which may be the last FREE block if we found no
;       larger free block. Update the next block's previous block pointer.
;
.190                    mov     [edi+MEMBLOCK.nextblock],ecx                    ;set the next block ptr
                        mov     ebx,[esi+MEMROOT.lastfree]                      ;assume all blocks smaller
                        jecxz   .200                                            ;branch if no block found
                        mov     ebx,[ecx+MEMBLOCK.previousblock]                ;next block's previous block ptr
                        mov     [ecx+MEMBLOCK.previousblock],edi                ;update next block's previous ptr
                        jmp     .210                                            ;continue
.200                    mov     [esi+MEMROOT.lastfree],edi                      ;this block is now the last free
;
;       Set our previous block pointer to either the previous pointer of the found block or the last free block.
;       If there is no previous block pointer, then this block now the first FREE block. Otherwise update that block's
;       next pointer.
;
.210                    mov     [edi+MEMBLOCK.previousblock],ebx                ;set the previous block ptr
                        test    ebx,ebx                                         ;do we have a previous block?
                        jz      .220                                            ;no, branch
                        mov     [ebx+MEMBLOCK.nextblock],edi                    ;update previous block's next block ptr
                        jmp     .230                                            ;continue
.220                    mov     [esi+MEMROOT.firstfree],edi                     ;update first free ptr
;
;       The memory free has completed.
;
.230                    xor     eax,eax                                         ;indicate success
;
;       Restore and return.
;
.240                    pop     es                                              ;restore non-volatile regs
                        pop     ds                                              ;
                        pop     edi                                             ;
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        pop     ebx                                             ;
                        ret                                                     ;return
;=======================================================================================================================
;
;       String Helper Routines
;
;       CompareMemory
;       CopyMemory
;       UpperCaseString
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        CompareMemory
;
;       Description:    This routine compares two byte arrays.
;
;       In:             DS:EDX  first source address
;                       DS:EBX  second source address
;                       ECX     comparison length
;
;       Out:            EDX     first source address
;                       EBX     second source address
;                       ECX     0       array 1 = array 2
;                               <0      array 1 < array 2
;                               >0      array 1 > array 2
;
;-----------------------------------------------------------------------------------------------------------------------
CompareMemory           push    esi                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    es                                              ;
                        push    ds                                              ;copy DS
                        pop     es                                              ;... to ES
                        mov     esi,edx                                         ;first source address
                        mov     edi,ebx                                         ;second source address
                        cld                                                     ;forward strings
                        rep     cmpsb                                           ;compare bytes
                        mov     al,0                                            ;default result
                        jz      .10                                             ;branch if arrays equal
                        mov     al,1                                            ;positive result
                        jnc     .10                                             ;branch if target > source
                        mov     al,-1                                           ;negative result
.10                     movsx   ecx,al                                          ;extend sign
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     esi                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        CopyMemory
;
;       Description:    This routine copies a byte array.
;
;       In:             DS:EDX  first source address
;                       DS:EBX  second source address
;                       ECX     copy length
;
;-----------------------------------------------------------------------------------------------------------------------
CopyMemory              push    ecx                                             ;save non-volatile regs
                        push    esi                                             ;
                        push    edi                                             ;
                        push    es                                              ;
;
;       Compare byte array
;
                        push    ds                                              ;load data selector
                        pop     es                                              ;... into ES register
                        mov     esi,edx                                         ;first source address
                        mov     edi,ebx                                         ;second source address
                        cld                                                     ;forward strings
                        rep     movsb                                           ;copy bytes
;
;       Restore and return
;
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        UpperCaseString
;
;       Description:    This routine places all characters in the given string to upper case.
;
;       In:             DS:EDX  string address
;
;       Out:            EDX     string address
;
;-----------------------------------------------------------------------------------------------------------------------
UpperCaseString         push    esi                                             ;save non-volatile regs
                        mov     esi,edx                                         ;string address
                        cld                                                     ;forward strings
.10                     lodsb                                                   ;string character
                        test    al,al                                           ;null?
                        jz      .20                                             ;yes, skip ahead
                        cmp     al,EASCIILOWERA                                 ;lower-case? (lower bounds)
                        jb      .10                                             ;no, continue
                        cmp     al,EASCIILOWERZ                                 ;lower-case? (upper bounds)
                        ja      .10                                             ;no, continue
                        and     al,EASCIICASEMASK                               ;mask for upper case
                        mov     [esi-1],al                                      ;upper character
                        jmp     .10                                             ;continue
.20                     pop     esi                                             ;restore non-volatile regs
                        ret                                                     ;return
;=======================================================================================================================
;
;       Console Helper Routines
;
;       FirstConsoleColumn
;       GetConsoleChar
;       GetConsoleString
;       NextConsoleColumn
;       NextConsoleRow
;       PreviousConsoleColumn
;       PutConsoleChar
;       PutConsoleHexByte
;       PutConsoleHexDword
;       PutConsoleHexWord
;       PutConsoleOIAChar
;       PutConsoleOIAShift
;       PutConsoleString
;       Yield
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        FirstConsoleColumn
;
;       Description:    This routine resets the console column to start of the row.
;
;       In:             DS      OS data selector
;
;-----------------------------------------------------------------------------------------------------------------------
FirstConsoleColumn      xor     al,al                                           ;zero column
                        mov     [wbConsoleColumn],al                            ;save column
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        GetConsoleChar
;
;       Description:    This routine waits for EMSGKEYCHAR message and return character code.
;
;       Out:            AL      ASCII character code
;                       AH      keyboard scan code
;
;-----------------------------------------------------------------------------------------------------------------------
GetConsoleChar.10       call    Yield                                           ;pass control or halt
GetConsoleChar          call    GetMessage                                      ;get the next message
                        or      eax,eax                                         ;do we have a message?
                        jz      GetConsoleChar.10                               ;no, skip ahead
                        push    eax                                             ;save key codes
                        and     eax,0FFFF0000h                                  ;mask for message type
                        cmp     eax,EMSGKEYCHAR                                 ;key-char message?
                        pop     eax                                             ;restore key codes
                        jne     GetConsoleChar                                  ;no, try again
                        and     eax,0000ffffh                                   ;mask for key codes
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        GetConsoleString
;
;       Description:    This routine accepts keyboard input into a buffer.
;
;       In:             DS:EDX  target buffer address
;                       ECX     maximum number of characters to accept
;                       BH      echo to terminal
;                       BL      terminating character
;
;-----------------------------------------------------------------------------------------------------------------------
GetConsoleString        push    ecx                                             ;save non-volatile regs
                        push    esi                                             ;
                        push    edi                                             ;
                        push    es                                              ;
                        push    ds                                              ;load data segment selector ...
                        pop     es                                              ;... into extra segment register
                        mov     edi,edx                                         ;edi = target buffer
                        push    ecx                                             ;save maximum characters
                        xor     al,al                                           ;zero register
                        cld                                                     ;forward strings
                        rep     stosb                                           ;zero fill buffer
                        pop     ecx                                             ;maximum characters
                        mov     edi,edx                                         ;edi = target buffer
                        mov     esi,edx                                         ;esi = target buffer
.10                     jecxz   .50                                             ;exit if max-length is zero
.20                     call    GetConsoleChar                                  ;al = next input char
                        cmp     al,bl                                           ;is this the terminator?
                        je      .50                                             ;yes, exit
                        cmp     al,EASCIIBACKSPACE                              ;is this a backspace?
                        jne     .30                                             ;no, skip ahead
                        cmp     esi,edi                                         ;at start of buffer?
                        je      .20                                             ;yes, get next character
                        dec     edi                                             ;backup target pointer
                        mov     byte [edi],0                                    ;zero previous character
                        inc     ecx                                             ;increment remaining chars
                        test    bh,1                                            ;echo to console?
                        jz      .20                                             ;no, get next character
                        call    PreviousConsoleColumn                           ;backup console position
                        mov     al,EASCIISPACE                                  ;ASCII space
                        call    PutConsoleChar                                  ;write space to console
                        call    PlaceCursor                                     ;position the cursor
                        jmp     .20                                             ;get next character
.30                     cmp     al,EASCIISPACE                                  ;printable? (lower bounds)
                        jb      .20                                             ;no, get another character
                        cmp     al,EASCIITILDE                                  ;printable? (upper bounds)
                        ja      .20                                             ;no, get another character
                        stosb                                                   ;store character in buffer
                        test    bh,1                                            ;echo to console?
                        jz      .40                                             ;no, skip ahead
                        call    PutConsoleChar                                  ;write character to console
                        call    NextConsoleColumn                               ;advance console position
                        call    PlaceCursor                                     ;position the cursor
.40                     dec     ecx                                             ;decrement remaining chars
                        jmp     .10                                             ;next
.50                     xor     al,al                                           ;null
                        stosb                                                   ;terminate buffer
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        NextConsoleColumn
;
;       Description:    This routine advances the console position one column. The columnn is reset to zero and the row
;                       incremented if the end of the current row is reached.
;
;       In:             DS      OS data selector
;
;-----------------------------------------------------------------------------------------------------------------------
NextConsoleColumn       mov     al,[wbConsoleColumn]                            ;current column
                        inc     al                                              ;increment column
                        mov     [wbConsoleColumn],al                            ;save column
                        cmp     al,ECONCOLS                                     ;end of row?
                        jb      .10                                             ;no, skip ahead
                        call    FirstConsoleColumn                              ;reset column to start of row
                        call    NextConsoleRow                                  ;line feed to next row
.10                     ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        NextConsoleRow
;
;       Description:    This routine advances the console position one line. Scroll the screen one row if needed.
;
;       In:             DS      OS data selector
;
;-----------------------------------------------------------------------------------------------------------------------
NextConsoleRow          mov     al,[wbConsoleRow]                               ;current row
                        inc     al                                              ;increment row
                        mov     [wbConsoleRow],al                               ;save row
                        cmp     al,ECONROWS                                     ;end of screen?
                        jb      .10                                             ;no, skip ahead
                        call    ScrollConsoleRow                                ;scroll up one row
                        mov     al,[wbConsoleRow]                               ;row
                        dec     al                                              ;decrement row
                        mov     [wbConsoleRow],al                               ;save row
.10                     ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PreviousConsoleColumn
;
;       Description:    This routine retreats the cursor one logical column. If the cursor was at the start of a row,
;                       the column is set to the last position in the row and the row is decremented.
;
;       In:             DS      OS data selector
;
;-----------------------------------------------------------------------------------------------------------------------
PreviousConsoleColumn   mov     al,[wbConsoleColumn]                            ;current column
                        or      al,al                                           ;start of row?
                        jnz     .10                                             ;no, skip ahead
                        mov     ah,[wbConsoleRow]                               ;current row
                        or      ah,ah                                           ;top of screen?
                        jz      .20                                             ;yes, exit with no change
                        dec     ah                                              ;decrement row
                        mov     [wbConsoleRow],ah                               ;save row
                        mov     al,ECONCOLS                                     ;set maximum column
.10                     dec     al                                              ;decrement column
                        mov     [wbConsoleColumn],al                            ;save column
.20                     ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutConsoleChar
;
;       Description:    This routine writes one ASCII character to the console screen.
;
;       In:             AL      ASCII character
;                       DS      OS data selector
;
;-----------------------------------------------------------------------------------------------------------------------
PutConsoleChar          push    ecx                                             ;save non-volatile regs
                        push    es                                              ;
                        push    EGDTCGA                                         ;load CGA selector ...
                        pop     es                                              ;... into extra segment reg
                        mov     cl,[wbConsoleColumn]                            ;column
                        mov     ch,[wbConsoleRow]                               ;row
                        call    SetConsoleChar                                  ;put character at row, column
                        pop     es                                              ;restore non-volatile regs
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutConsoleHexByte
;
;       Description:    This routine writes two ASCII characters to the console representing a byte value.
;
;       In:             AL      byte value
;                       CL      column
;                       CH      row
;                       DS      OS data selector
;                       ES      CGA selector
;
;-----------------------------------------------------------------------------------------------------------------------
PutConsoleHexByte       push    ebx                                             ;save non-volatile regs
                        mov     bl,al                                           ;save byte value
                        shr     al,4                                            ;hi-order nybble
                        or      al,030h                                         ;apply ASCII zone
                        cmp     al,03ah                                         ;numeric?
                        jb      .10                                             ;yes, skip ahead
                        add     al,7                                            ;add ASCII offset for alpha
.10                     call    SetConsoleChar                                  ;display ASCII character
                        mov     al,bl                                           ;byte value
                        and     al,0fh                                          ;lo-order nybble
                        or      al,30h                                          ;apply ASCII zone
                        cmp     al,03ah                                         ;numeric?
                        jb      .20                                             ;yes, skip ahead
                        add     al,7                                            ;add ASCII offset for alpha
.20                     call    SetConsoleChar                                  ;display ASCII character
                        pop     ebx                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutConsoleHexDword
;
;       Description:    This routine writes eight ASCII characters to the console representing a doubleword value.
;
;       In:             EAX     value
;                       CL      column
;                       CH      row
;                       DS      OS data selector
;                       ES      CGA selector
;
;-----------------------------------------------------------------------------------------------------------------------
PutConsoleHexDword      push    eax
                        shr     eax,16
                        call    PutConsoleHexWord
                        pop     eax
                        call    PutConsoleHexWord
                        ret
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutConsoleHexWord
;
;       Description:    This routine writes four ASCII characters to the console representing a word value.
;
;       In:             EAX     value
;                       CL      column
;                       CH      row
;                       DS      OS data selector
;                       ES      CGA selector
;
;-----------------------------------------------------------------------------------------------------------------------
PutConsoleHexWord       push    eax
                        shr     eax,8
                        call    PutConsoleHexByte
                        pop     eax
                        call    PutConsoleHexByte
                        ret
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutConsoleOIAChar
;
;       Description:    This routine updates the Operator Information Area (OIA).
;
;       In:             DS      OS data selector
;
;-----------------------------------------------------------------------------------------------------------------------
PutConsoleOIAChar       push    ebx                                             ;save non-volatile regs
                        push    ecx                                             ;
                        push    esi                                             ;
                        push    ds                                              ;
                        push    es                                              ;
                        push    EGDTOSDATA                                      ;load OS data selector ...
                        pop     ds                                              ;... into data segment register
                        push    EGDTCGA                                         ;load CGA selector ...
                        pop     es                                              ;... into extra segment register
                        mov     esi,wbConsoleScan0                              ;scan codes address
                        mov     bh,ECONOIAROW                                   ;OIA row
                        mov     bl,0                                            ;starting column
                        mov     ecx,6                                           ;maximum scan codes
.10                     push    ecx                                             ;save remaining count
                        mov     ecx,ebx                                         ;row, column
                        lodsb                                                   ;read scan code
                        or      al,al                                           ;scan code present?
                        jz      .20                                             ;no, skip ahead
                        call    PutConsoleHexByte                               ;display scan code
                        jmp     .30                                             ;continue
.20                     mov     al,' '                                          ;ASCII space
                        call    SetConsoleChar                                  ;display space
                        mov     al,' '                                          ;ASCII space
                        call    SetConsoleChar                                  ;display space
.30                     add     bl,2                                            ;next column (+2)
                        pop     ecx                                             ;restore remaining
                        loop    .10                                             ;next code
                        mov     al,[wbConsoleChar]                              ;console ASCII character
                        cmp     al,32                                           ;printable? (lower-bounds)
                        jb      .40                                             ;no, skip ahead
                        cmp     al,126                                          ;printable? (upper-bounds)
                        ja      .40                                             ;no, skip ahead
                        mov     ch,bh                                           ;OIA row
                        mov     cl,40                                           ;character display column
                        call    SetConsoleChar                                  ;display ASCII character
.40                     pop     es                                              ;restore non-volatile regs
                        pop     ds                                              ;
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        pop     ebx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutConsoleOIAShift
;
;       Description:    This routine updates the shift/ctrl/alt/lock indicators in the operator information area (OIA).
;
;       In:             BL      shift flags
;                       BH      lock flags
;                       DS      OS data selector
;
;-----------------------------------------------------------------------------------------------------------------------
PutConsoleOIAShift      push    ecx                                             ;save non-volatile regs
                        push    es                                              ;
                        push    EGDTCGA                                         ;load CGA selector ...
                        pop     es                                              ;... into ES register
                        mov     ch,ECONOIAROW                                   ;OIA row
                        mov     al,EASCIISPACE                                  ;space is default character
                        test    bl,EKEYFSHIFTLEFT                               ;left-shift indicated?
                        jz      .10                                             ;no, skip ahead
                        mov     al,'S'                                          ;yes, indicate with 'S'
.10                     mov     cl,14                                           ;indicator column
                        call    SetConsoleChar                                  ;display ASCII character
                        mov     al,EASCIISPACE                                  ;ASCII space
                        test    bl,EKEYFSHIFTRIGHT                              ;right-shift indicated?
                        jz      .20                                             ;no, skip ahead
                        mov     al,'S'                                          ;yes, indicate with 'S'
.20                     mov     cl,64                                           ;indicator column
                        call    SetConsoleChar                                  ;display ASCII character
                        mov     al,EASCIISPACE                                  ;ASCII space
                        test    bl,EKEYFCTRLLEFT                                ;left-ctrl indicated?
                        jz      .30                                             ;no, skip ahead
                        mov     al,'C'                                          ;yes, indicate with 'C'
.30                     mov     cl,15                                           ;indicator column
                        call    SetConsoleChar                                  ;display ASCII character
                        mov     al,EASCIISPACE                                  ;ASCII space
                        test    bl,EKEYFCTRLRIGHT                               ;right-ctrl indicated?
                        jz      .40                                             ;no, skip ahead
                        mov     al,'C'                                          ;yes, indicate with 'C'
.40                     mov     cl,63                                           ;indicator column
                        call    SetConsoleChar                                  ;display ASCII character
                        mov     al,EASCIISPACE                                  ;ASCII space
                        test    bl,EKEYFALTLEFT                                 ;left-alt indicated?
                        jz      .50                                             ;no, skip ahead
                        mov     al,'A'                                          ;yes, indicate with 'A'
.50                     mov     cl,16                                           ;indicator column
                        call    SetConsoleChar                                  ;display ASCII character
                        mov     al,EASCIISPACE                                  ;ASCII space
                        test    bl,EKEYFALTRIGHT                                ;right-alt indicated?
                        jz      .60                                             ;no, skip ahead
                        mov     al,'A'                                          ;yes, indicate with 'A'
.60                     mov     cl,62                                           ;indicator column
                        call    SetConsoleChar                                  ;display ASCII character
                        mov     al,EASCIISPACE                                  ;ASCII space
                        test    bh,EKEYFLOCKCAPS                                ;caps-lock indicated?
                        jz      .70                                             ;no, skip ahead
                        mov     al,'C'                                          ;yes, indicate with 'C'
.70                     mov     cl,78                                           ;indicator column
                        call    SetConsoleChar                                  ;display ASCII character
                        mov     al,EASCIISPACE                                  ;ASCII space
                        test    bh,EKEYFLOCKNUM                                 ;num-lock indicated?
                        jz      .80                                             ;no, skip ahead
                        mov     al,'N'                                          ;yes, indicate with 'N'
.80                     mov     cl,77                                           ;indicator column
                        call    SetConsoleChar                                  ;display ASCII character
                        mov     al,EASCIISPACE                                  ;ASCII space
                        test    bh,EKEYFLOCKSCROLL                              ;scroll-lock indicated?
                        jz      .90                                             ;no, skip ahead
                        mov     al,'S'                                          ;yes, indicate with 'S'
.90                     mov     cl,76                                           ;indicator column
                        call    SetConsoleChar                                  ;display ASCII character
                        pop     es                                              ;restore non-volatile regs
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutConsoleString
;
;       Description:    This routine writes a sequence of ASCII characters to the console until null and updates the
;                       console position as needed.
;
;       In:             EDX     source address
;                       DS      OS data selector
;
;-----------------------------------------------------------------------------------------------------------------------
PutConsoleString        push    esi                                             ;save non-volatile regs
                        mov     esi,edx                                         ;source address
                        cld                                                     ;forward strings
.10                     lodsb                                                   ;ASCII character
                        or      al,al                                           ;end of string?
                        jz      .40                                             ;yes, skip ahead
                        cmp     al,EASCIIRETURN                                 ;carriage return?
                        jne     .20                                             ;no, skip ahead
                        call    FirstConsoleColumn                              ;move to start of row
                        jmp     .10                                             ;next character
.20                     cmp     al,EASCIILINEFEED                               ;line feed?
                        jne     .30                                             ;no, skip ahead
                        call    NextConsoleRow                                  ;move to next row
                        jmp     .10                                             ;next character
.30                     call    PutConsoleChar                                  ;output character to console
                        call    NextConsoleColumn                               ;advance to next column
                        jmp     .10                                             ;next character
.40                     pop     esi                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        Yield
;
;       Description:    This routine passes control to the next ready task or enter halt.
;
;-----------------------------------------------------------------------------------------------------------------------
Yield                   sti                                                     ;enable maskagle interrupts
                        hlt                                                     ;halt until external interrupt
                        ret                                                     ;return
;=======================================================================================================================
;
;       Data-Type Conversion Helper Routines
;
;       DecimalToUnsigned
;       HexadecimalToUnsigned
;       UnsignedToDecimalString
;       UnsignedToHexadecimal
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        DecimalToUnsigned
;
;       Description:    This routine returns an unsigned integer of the value of the input ASCIIZ decimal string.
;
;       Input:          DS:EDX  null-terminated decimal string address
;
;       Output:         EAX     unsigned integer value
;
;-----------------------------------------------------------------------------------------------------------------------
DecimalToUnsigned       push    esi                                             ;save non-volatile regs
                        mov     esi,edx                                         ;source address
                        xor     edx,edx                                         ;zero total
.10                     lodsb                                                   ;source byte
                        cmp     al,','                                          ;comma?
                        je      .10                                             ;yes, ignore
                        test    al,al                                           ;end of string?
                        jz      .30                                             ;yes, done
                        cmp     al,'.'                                          ;decimal point?
                        je      .30                                             ;yes, done
                        cmp     al,'0'                                          ;numeral?
                        jb      .20                                             ;no, invalid string
                        cmp     al,'9'                                          ;numeral?
                        ja      .20                                             ;no, invalid string
                        and     al,00Fh                                         ;mask ASCII zone
                        push    eax                                             ;save numeral
                        shl     edx,1                                           ;total * 2
                        mov     eax,edx                                         ;total * 2
                        shl     edx,2                                           ;total * 8
                        add     edx,eax                                         ;total * 10
                        pop     eax                                             ;restore numeral
                        add     edx,eax                                         ;accumulate decimal digit
                        xor     eax,eax                                         ;zero register
                        jmp     .10                                             ;next
.20                     xor     edx,edx                                         ;zero result on error
.30                     mov     eax,edx                                         ;result
                        pop     esi                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        HexadecimalToUnsigned
;
;       Description:    This routine returns an unsigned integer of the value of the input ASCIIZ hexadecimal string.
;
;       Input:          DS:EDX  null-terminated hexadecimal string address
;
;       Output:         EAX     unsigned integer value
;
;-----------------------------------------------------------------------------------------------------------------------
HexadecimalToUnsigned   push    esi                                             ;save non-volatile regs
                        mov     esi,edx                                         ;source address
                        xor     edx,edx                                         ;zero register
.10                     lodsb                                                   ;source byte
                        test    al,al                                           ;end of string?
                        jz      .30                                             ;yes, branch
                        cmp     al,'9'                                          ;hexadecimal?
                        jna     .20                                             ;no, skip ahead
                        sub     al,37h                                          ;'A' = 41h, less 37h = 0Ah
.20                     and     eax,0fh                                         ;remove ascii zone
                        shl     edx,4                                           ;previous total x 16
                        add     edx,eax                                         ;add prior value x 16
                        jmp     .10                                             ;next
.30                     mov     eax,edx                                         ;result
                        pop     esi                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        UnsignedToDecimalString
;
;       Description:    This routine creates an ASCIIZ string representing the decimal value of 32-bit binary input.
;
;       Input:          BH      flags           bit 0: 1 = trim leading zeros
;                                               bit 1: 1 = include comma grouping delimiters
;                                               bit 4: 1 = non-zero digit found (internal)
;                       ECX     32-bit binary
;                       DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
UnsignedToDecimalString push    ebx                                             ;save non-volatile regs
                        push    ecx                                             ;
                        push    edi                                             ;
                        push    es                                              ;
                        push    ds                                              ;load data selector
                        pop     es                                              ;... into extra segment reg
                        mov     edi,edx                                         ;output buffer address
                        and     bh,00001111b                                    ;zero internal flags
                        mov     edx,ecx                                         ;binary
                        mov     ecx,1000000000                                  ;10^9 divisor
                        call    .30                                             ;divide and store
                        mov     ecx,100000000                                   ;10^8 divisor
                        call    .10                                             ;divide and store
                        mov     ecx,10000000                                    ;10^7 divisor
                        call    .30                                             ;divide and store
                        mov     ecx,1000000                                     ;10^6 divisor
                        call    .30                                             ;divide and store
                        mov     ecx,100000                                      ;10^5 divisor
                        call    .10                                             ;divide and store
                        mov     ecx,10000                                       ;10^4 divisor
                        call    .30                                             ;divide and store
                        mov     ecx,1000                                        ;10^3 divisor
                        call    .30                                             ;divide and store
                        mov     ecx,100                                         ;10^2 divisor
                        call    .10                                             ;divide and store
                        mov     ecx,10                                          ;10^2 divisor
                        call    .30                                             ;divide and store
                        mov     eax,edx                                         ;10^1 remainder
                        call    .40                                             ;store
                        xor     al,al                                           ;null terminator
                        stosb
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     ecx                                             ;
                        pop     ebx                                             ;
                        ret                                                     ;return
.10                     test    bh,00000010b                                    ;comma group delims?
                        jz      .30                                             ;no, branch
                        test    bh,00000001b                                    ;trim leading zeros?
                        jz      .20                                             ;no, store delim
                        test    bh,00010000b                                    ;non-zero found?
                        jz      .30                                             ;no, branch
.20                     mov     al,','                                          ;delimiter
                        stosb                                                   ;store delimiter
.30                     mov     eax,edx                                         ;lo-orer dividend
                        xor     edx,edx                                         ;zero hi-order
                        div     ecx                                             ;divide by power of 10
                        test    al,al                                           ;zero?
                        jz      .50                                             ;yes, branch
                        or      bh,00010000b                                    ;non-zero found
.40                     or      al,30h                                          ;ASCII zone
                        stosb                                                   ;store digit
                        ret                                                     ;return
.50                     test    bh,00000001b                                    ;trim leading zeros?
                        jz      .40                                             ;no, store and continue
                        test    bh,00010000b                                    ;non-zero found?
                        jnz     .40                                             ;yes, store and continue
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        UnsignedToHexadecimal
;
;       Description:    This routine creates an ASCIIZ string representing the hexadecimal value of binary input
;
;       Input:          DS:EDX  output buffer address
;                       ECX     32-bit binary
;
;-----------------------------------------------------------------------------------------------------------------------
UnsignedToHexadecimal   push    edi                                             ;store non-volatile regs
                        mov     edi,edx                                         ;output buffer address
                        mov     edx,ecx                                         ;32-bit unsigned
                        xor     ecx,ecx                                         ;zero register
                        mov     cl,8                                            ;nybble count
.10                     rol     edx,4                                           ;next hi-order nybble in bits 0-3
                        mov     al,dl                                           ;????bbbb
                        and     al,0fh                                          ;mask out bits 4-7
                        or      al,30h                                          ;mask in ascii zone
                        cmp     al,3ah                                          ;A through F?
                        jb      .20                                             ;no, skip ahead
                        add     al,7                                            ;41h through 46h
.20                     stosb                                                   ;store hexnum
                        loop    .10                                             ;next nybble
                        xor     al,al                                           ;zero reg
                        stosb                                                   ;null terminate
                        pop     edi                                             ;restore non-volatile regs
                        ret                                                     ;return
;=======================================================================================================================
;
;       Message Queue Helper Routines
;
;       GetMessage
;       PutMessage
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        GetMessage
;
;       Description:    This routine reads and removes a message from the message queue.
;
;       Out:            EAX     lo-order message data
;                       EDX     hi-order message data
;
;                       CY      0 = message read
;                               1 = no message to read
;
;-----------------------------------------------------------------------------------------------------------------------
GetMessage              push    ebx                                             ;save non-volatile regs
                        push    ecx                                             ;
                        push    ds                                              ;
                        push    ELDTMQ                                          ;load message queue selector ...
                        pop     ds                                              ;... into data segment register
                        mov     ebx,[MQHead]                                    ;head ptr
                        mov     eax,[ebx]                                       ;lo-order 32 bits
                        mov     edx,[ebx+4]                                     ;hi-order 32 bits
                        or      eax,edx                                         ;is queue empty?
                        stc                                                     ;assume queue is emtpy
                        jz      .20                                             ;yes, skip ahead
                        xor     ecx,ecx                                         ;store zero
                        mov     [ebx],ecx                                       ;... in lo-order dword
                        mov     [ebx+4],ecx                                     ;... in hi-order dword
                        add     ebx,8                                           ;next queue element
                        and     ebx,03fch                                       ;at end of queue?
                        jnz     .10                                             ;no, skip ahead
                        mov     bl,8                                            ;reset to 1st entry
.10                     mov     [MQHead],ebx                                    ;save new head ptr
                        clc                                                     ;indicate message read
.20                     pop     ds                                              ;restore non-volatile regs
                        pop     ecx                                             ;
                        pop     ebx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutMessage
;
;       Description:    This routine adda a message to the message queue.
;
;       In:             ECX     hi-order data word
;                       EDX     lo-order data word
;
;       Out:            CY      0 = success
;                               1 = fail: queue is full
;
;-----------------------------------------------------------------------------------------------------------------------
PutMessage              push    ds                                              ;save non-volatile regs
                        push    ELDTMQ                                          ;load task message queue selector ...
                        pop     ds                                              ;... into data segment register
                        mov     eax,[MQTail]                                    ;tail ptr
                        cmp     dword [eax],0                                   ;is queue full?
                        stc                                                     ;assume failure
                        jne     .20                                             ;yes, cannot store
                        mov     [eax],edx                                       ;store lo-order data
                        mov     [eax+4],ecx                                     ;store hi-order data
                        add     eax,8                                           ;next queue element adr
                        and     eax,03fch                                       ;at end of queue?
                        jnz     .10                                             ;no, skip ahead
                        mov     al,8                                            ;reset to top of queue
.10                     mov     [MQTail],eax                                    ;save new tail ptr
                        clc                                                     ;indicate success
.20                     pop     ds                                              ;restore non-volatile regs
                        ret                                                     ;return
;=======================================================================================================================
;
;       Memory-Mapped Video Routines
;
;       These routines read and/or write directly to CGA video memory (B800:0)
;
;       ClearConsoleScreen
;       ScrollConsoleRow
;       SetConsoleChar
;       SetConsoleString
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ClearConsoleScreen
;
;       Description:    This routine clears the console (CGA) screen.
;
;-----------------------------------------------------------------------------------------------------------------------
ClearConsoleScreen      push    ecx                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    ds                                              ;
                        push    es                                              ;
                        push    EGDTOSDATA                                      ;load OS Data selector ...
                        pop     ds                                              ;... into DS register
                        push    EGDTCGA                                         ;load CGA selector ...
                        pop     es                                              ;... into ES register
                        mov     eax,ECONCLEARDWORD                              ;initializtion value
                        mov     ecx,ECONROWDWORDS*(ECONROWS)                    ;double-words to clear
                        xor     edi,edi                                         ;target offset
                        cld                                                     ;forward strings
                        rep     stosd                                           ;reset screen body
                        mov     eax,ECONOIADWORD                                ;OIA attribute and space
                        mov     ecx,ECONROWDWORDS                               ;double-words per row
                        rep     stosd                                           ;reset OIA line
                        xor     al,al                                           ;zero register
                        mov     [wbConsoleRow],al                               ;reset console row
                        mov     [wbConsoleColumn],al                            ;reset console column
                        call    PlaceCursor                                     ;place cursor at current position
                        pop     es                                              ;restore non-volatile regs
                        pop     ds                                              ;
                        pop     edi                                             ;
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ScrollConsoleRow
;
;       Description:    This routine scrolls the console (text) screen up one row.
;
;-----------------------------------------------------------------------------------------------------------------------
ScrollConsoleRow        push    ecx                                             ;save non-volatile regs
                        push    esi                                             ;
                        push    edi                                             ;
                        push    ds                                              ;
                        push    es                                              ;
                        push    EGDTCGA                                         ;load CGA video selector ...
                        pop     ds                                              ;... into DS
                        push    EGDTCGA                                         ;load CGA video selector ...
                        pop     es                                              ;... into ES
                        mov     ecx,ECONROWDWORDS*(ECONROWS-1)                  ;double-words to move
                        mov     esi,ECONROWBYTES                                ;ESI = source (line 2)
                        xor     edi,edi                                         ;EDI = target (line 1)
                        cld                                                     ;forward strings
                        rep     movsd                                           ;move 24 lines up
                        mov     eax,ECONCLEARDWORD                              ;attribute and ASCII space
                        mov     ecx,ECONROWDWORDS                               ;double-words per row
                        rep     stosd                                           ;clear bottom row
                        pop     es                                              ;restore non-volatile regs
                        pop     ds                                              ;
                        pop     edi                                             ;
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        SetConsoleChar
;
;       Description:    This routine outputs an ASCII character at the given row and column.
;
;       In:             AL      ASCII character
;                       CL      column
;                       CH      row
;                       ES      CGA selector
;
;       Out:            EAX     last target address written (ES:)
;                       CL      column + 1
;
;-----------------------------------------------------------------------------------------------------------------------
SetConsoleChar          mov     dl,al                                           ;ASCII character
                        movzx   eax,ch                                          ;row
                        mov     ah,ECONCOLS                                     ;cols/row
                        mul     ah                                              ;row * cols/row
                        add     al,cl                                           ;add column
                        adc     ah,0                                            ;handle carry
                        shl     eax,1                                           ;screen offset
                        mov     [es:eax],dl                                     ;store character
                        inc     cl                                              ;next column
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        SetConsoleString
;
;       Description:    This routine outputs a sequence of ASCII character at the given row and column.
;
;       In:             ESI     source offset (DS:)
;                       CL      column
;                       CH      row
;                       ES      CGA selector
;
;-----------------------------------------------------------------------------------------------------------------------
SetConsoleString        push    esi                                             ;save non-volatile regs
                        cld                                                     ;forward strings
.10                     lodsb                                                   ;next ASCII character
                        test    al,al                                           ;end of string?
                        jz      .20                                             ;yes, branch
                        call    SetConsoleChar                                  ;store character
                        jmp     .10                                             ;continue
.20                     pop     esi                                             ;restore non-volatile regs
                        ret                                                     ;return
;=======================================================================================================================
;
;       Input/Output Routines
;
;       These routines read and/or write directly to ports.
;
;       GetBaseMemSize
;       GetExtendedMemSize
;       GetROMMemSize
;       PlaceCursor
;       PutPrimaryEndOfInt
;       PutSecondaryEndOfInt
;       ReadRealTimeClock
;       ResetSystem
;       SetKeyboardLamps
;       WaitForKeyInBuffer
;       WaitForKeyOutBuffer
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        GetBaseMemSize
;
;       Description:    Return the amount of base RAM as reported by the CMOS.
;
;       Output:         EAX     base RAM size in bytes
;
;-----------------------------------------------------------------------------------------------------------------------
GetBaseMemSize          xor     eax,eax                                         ;zero register
                        mov     al,ERTCBASERAMHI                                ;base RAM high register
                        out     ERTCREGPORT,al                                  ;select base RAM high register
                        in      al,ERTCDATAPORT                                 ;read base RAM high (KB)
                        mov     ah,al                                           ;save base RAM high
                        mov     al,ERTCBASERAMLO                                ;base RAM low register
                        out     ERTCREGPORT,al                                  ;select base RAM low register
                        in      al,ERTCDATAPORT                                 ;read base RAM low (KB)
                        ret                                                     ;return to caller
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        GetExtendedMemSize
;
;       Description:    Return the amount of extended RAM as reported by the CMOS.
;
;       Output:         EAX     extended RAM size in bytes
;
;-----------------------------------------------------------------------------------------------------------------------
GetExtendedMemSize      xor     eax,eax                                         ;zero register
                        mov     al,ERTCEXTRAMHI                                 ;extended RAM high register
                        out     ERTCREGPORT,al                                  ;select extended RAM high register
                        in      al,ERTCDATAPORT                                 ;read extended RAM high (KB)
                        mov     ah,al                                           ;save extended RAM high
                        mov     al,ERTCEXTRAMLO                                 ;extended RAM low register
                        out     ERTCREGPORT,al                                  ;select extended RAM low register
                        in      al,ERTCDATAPORT                                 ;read extended RAM low (KB)
                        ret                                                     ;return to caller
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        GetROMMemSize
;
;       Description:    Return the amount of RAM as reported by the BIOS during power-up.
;
;       Output:         EAX     RAM size in bytes
;
;-----------------------------------------------------------------------------------------------------------------------
GetROMMemSize           xor     eax,eax                                         ;zero register
                        mov     ax,[wwROMMemSize]                               ;memory size (KB) as returned by INT 12h
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PlaceCursor
;
;       Description:    This routine positions the cursor on the console.
;
;       In:             DS      OS data selector
;
;-----------------------------------------------------------------------------------------------------------------------
PlaceCursor             push    ecx                                             ;save non-volatile regs
                        mov     al,[wbConsoleRow]                               ;AL = row
                        mov     ah,ECONCOLS                                     ;AH = cols/row
                        mul     ah                                              ;row offset
                        add     al,[wbConsoleColumn]                            ;add column
                        adc     ah,0                                            ;add overflow
                        mov     ecx,eax                                         ;screen offset
                        mov     dl,ECRTPORTLO                                   ;crt controller port lo
                        mov     dh,ECRTPORTHI                                   ;crt controller port hi
                        mov     al,ECRTCURLOCHI                                 ;crt cursor loc reg hi
                        out     dx,al                                           ;select register
                        inc     edx                                             ;data port
                        mov     al,ch                                           ;hi-order cursor loc
                        out     dx,al                                           ;store hi-order loc
                        dec     edx                                             ;register select port
                        mov     al,ECRTCURLOCLO                                 ;crt cursor loc reg lo
                        out     dx,al                                           ;select register
                        inc     edx                                             ;data port
                        mov     al,cl                                           ;lo-order cursor loc
                        out     dx,al                                           ;store lo-order loc
                        pop     ecx                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutPrimaryEndOfInt
;
;       Description:    This routine sends a non-specific end-of-interrupt signal to the primary PIC.
;
;-----------------------------------------------------------------------------------------------------------------------
PutPrimaryEndOfInt      sti                                                     ;enable maskable interrupts
                        mov     al,EPICEOI                                      ;non-specific end-of-interrupt
                        out     EPICPORTPRI,al                                  ;send EOI to primary PIC
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        PutSecondaryEndOfInt
;
;       Description:    This routine sends a non-specific end-of-interrupt signal to the secondary PIC.
;
;-----------------------------------------------------------------------------------------------------------------------
PutSecondaryEndOfInt    sti                                                     ;enable maskable interrupts
                        mov     al,EPICEOI                                      ;non-specific end-of-interrupt
                        out     EPICPORTSEC,al                                  ;send EOI to secondary PIC
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ReadRealTimeClock
;
;       Description:    This routine gets current date time from the real-time clock.
;
;       In:             DS:EBX  DATETIME structure
;
;-----------------------------------------------------------------------------------------------------------------------
ReadRealTimeClock       push    esi                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    es                                              ;
                        push    ds                                              ;store data selector ...
                        pop     es                                              ;... in es register
                        mov     edi,ebx                                         ;date-time structure
                        mov     al,ERTCSECONDREG                                ;second register
                        out     ERTCREGPORT,al                                  ;select second register
                        in      al,ERTCDATAPORT                                 ;read second register
                        cld                                                     ;forward strings
                        stosb                                                   ;store second value
                        mov     al,ERTCMINUTEREG                                ;minute register
                        out     ERTCREGPORT,al                                  ;select minute register
                        in      al,ERTCDATAPORT                                 ;read minute register
                        stosb                                                   ;store minute value
                        mov     al,ERTCHOURREG                                  ;hour register
                        out     ERTCREGPORT,al                                  ;select hour register
                        in      al,ERTCDATAPORT                                 ;read hour register
                        stosb                                                   ;store hour value
                        mov     al,ERTCWEEKDAYREG                               ;weekday register
                        out     ERTCREGPORT,al                                  ;select weekday register
                        in      al,ERTCDATAPORT                                 ;read weekday register
                        stosb                                                   ;store weekday value
                        mov     al,ERTCDAYREG                                   ;day register
                        out     ERTCREGPORT,al                                  ;select day register
                        in      al,ERTCDATAPORT                                 ;read day register
                        stosb                                                   ;store day value
                        mov     al,ERTCMONTHREG                                 ;month register
                        out     ERTCREGPORT,al                                  ;select month register
                        in      al,ERTCDATAPORT                                 ;read month register
                        stosb                                                   ;store month value
                        mov     al,ERTCYEARREG                                  ;year register
                        out     ERTCREGPORT,al                                  ;select year register
                        in      al,ERTCDATAPORT                                 ;read year register
                        stosb                                                   ;store year value
                        mov     al,ERTCCENTURYREG                               ;century register
                        out     ERTCREGPORT,al                                  ;select century register
                        in      al,ERTCDATAPORT                                 ;read century register
                        stosb                                                   ;store century value
                        mov     al,ERTCSTATUSREG                                ;status register
                        out     ERTCREGPORT,al                                  ;select status register
                        in      al,ERTCDATAPORT                                 ;read status register
                        test    al,ERTCBINARYVALS                               ;test if values are binary
                        jnz     .20                                             ;skip ahead if binary values
                        mov     esi,ebx                                         ;date-time structure address
                        mov     edi,ebx                                         ;date-time structure address
                        mov     ecx,8                                           ;loop counter
.10                     lodsb                                                   ;BCD value
                        mov     ah,al                                           ;BCD value
                        and     al,00001111b                                    ;low-order decimal zone
                        and     ah,11110000b                                    ;hi-order decimal zone
                        shr     ah,1                                            ;hi-order decimal * 8
                        add     al,ah                                           ;low-order + hi-order * 8
                        shr     ah,2                                            ;hi-order decimal * 2
                        add     al,ah                                           ;low-order + hi-order * 10
                        stosb                                                   ;replace BCD with binary
                        loop    .10                                             ;next value
.20                     pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     esi                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ResetSystem
;
;       Description:    This routine restarts the system using the 8042 controller.
;
;       Out:            N/A     This routine does not return.
;
;-----------------------------------------------------------------------------------------------------------------------
ResetSystem             mov     ecx,001fffffh                                   ;delay to clear ints
                        loop    $                                               ;clear interrupts
                        mov     al,EKEYBCMDRESET                                ;mask out bit zero
                        out     EKEYBPORTSTAT,al                                ;drive bit zero low
.10                     sti                                                     ;enable maskable interrupts
                        hlt                                                     ;halt until interrupt
                        jmp     .10                                             ;repeat until reset kicks in
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        SetKeyboardLamps
;
;       Description:    This routine sends the set/reset mode indicators command to the keyboard device.
;
;       In:             BH      00000CNS (C:Caps Lock,N:Num Lock,S:Scroll Lock)
;
;-----------------------------------------------------------------------------------------------------------------------
SetKeyboardLamps        call    WaitForKeyInBuffer                              ;wait for input buffer ready
                        mov     al,EKEYBCMDLAMPS                                ;set/reset lamps command
                        out     EKEYBPORTDATA,al                                ;send command to 8042
                        call    WaitForKeyOutBuffer                             ;wait for 8042 result
                        in      al,EKEYBPORTDATA                                ;read 8042 'ACK' (0fah)
                        call    WaitForKeyInBuffer                              ;wait for input buffer ready
                        mov     al,bh                                           ;set/reset lamps value
                        out     EKEYBPORTDATA,al                                ;send lamps value
                        call    WaitForKeyOutBuffer                             ;wait for 8042 result
                        in      al,EKEYBPORTDATA                                ;read 8042 'ACK' (0fah)
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        WaitForKeyInBuffer
;
;       Description:    This routine waits for keyboard input buffer to be ready for input.
;
;       Out:            ZF      1 = Input buffer ready
;                               0 = Input buffer not ready after timeout
;
;-----------------------------------------------------------------------------------------------------------------------
WaitForKeyInBuffer      push    ecx                                             ;save non-volatile regs
                        mov     ecx,EKEYBWAITLOOP                               ;keyboard controller timeout
.10                     in      al,EKEYBPORTSTAT                                ;keyboard status byte
                        test    al,EKEYBBITIN                                   ;is input buffer still full?
                        loopnz  .10                                             ;yes, repeat till timeout
                        pop     ecx                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        WaitForKeyOutBuffer
;
;       Description:    This routine waits for keyboard output buffer to have data to read.
;
;       Out:            ZF      1 = Output buffer has data from controller
;                               0 = Output buffer empty after timeout
;
;-----------------------------------------------------------------------------------------------------------------------
WaitForKeyOutBuffer     push    ecx                                             ;save non-volatile regs
                        mov     ecx,EKEYBWAITLOOP                               ;keyboard controller timeout
.10                     in      al,EKEYBPORTSTAT                                ;keyboard status byte
                        test    al,EKEYBBITOUT                                  ;output buffer status bit
                        loopz   .10                                             ;loop until output buffer bit
                        pop     ecx                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       End of the Kernel Function Library
;
;-----------------------------------------------------------------------------------------------------------------------
                        times   8192-($-$$) db 0h                               ;zero fill to end of section
;=======================================================================================================================
;
;       Console Task
;
;       The only task defined in the kernel is the console task. This task consists of code, data, stack, and task state
;       segments and a local descriptor table. The console task accepts and echos user keyboard input to the console
;       screen and responds to user commands.
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Console Stack                                                           @disk: 007600   @mem:  004000
;
;       This is the stack for the console task. It supports 448 nested calls.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 constack                                                ;console task stack
                        times   1792-($-$$) db 0h                               ;zero fill to end of section
;-----------------------------------------------------------------------------------------------------------------------
;
;       Console Local Descriptor Table                                          @disk: 007d00   @mem:  004700
;
;       This is the LDT for the console task. It defines the stack, code, data and queue segments as well as data
;       aliases for the TSS LDT. Data aliases allow inspection and altering of the TSS and LDT. This LDT can hold up to
;       16 descriptors. Six are initially defined.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 conldt                                                  ;console local descriptors
                        dq      004093004780007Fh                               ;04 TSS alias
                        dq      004093004700007Fh                               ;0c LDT alias
                        dq      00409300400006FFh                               ;14 stack
                        dq      00CF93000000FFFFh                               ;1c data
                        dq      00409B0050000FFFh                               ;24 code
                        dq      00409300480007FFh                               ;2c message queue
                        times   128-($-$$) db 0h                                ;zero fill to end of section
;-----------------------------------------------------------------------------------------------------------------------
;
;       Console Task State Segment                                              @disk: 007d80   @mem:  004780
;
;       This is the TSS for the console task. All rings share the same stack. DS and ES are set to the console data
;       segment. CS to console code.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 contss                                                  ;console task state segment
                        dd      0                                               ;00 back-link tss
                        dd      0700h                                           ;04 esp ring 0
                        dd      0014h                                           ;08 ss ring 0
                        dd      0700h                                           ;0c esp ring 1
                        dd      0014h                                           ;10 es ring 1
                        dd      0700h                                           ;14 esp ring 2
                        dd      0014h                                           ;18 ss ring 2
                        dd      0                                               ;1c cr ring 3
                        dd      0                                               ;20 eip
                        dd      0200h                                           ;24 eflags
                        dd      0                                               ;28 eax
                        dd      0                                               ;2c ecx
                        dd      0                                               ;30 edx
                        dd      0                                               ;34 ebx
                        dd      0700h                                           ;38 esp ring 3
                        dd      0                                               ;3c ebp
                        dd      0                                               ;40 esi
                        dd      0                                               ;44 edi
                        dd      001Ch                                           ;48 es
                        dd      0024h                                           ;4c cs
                        dd      0014h                                           ;50 ss ring 3
                        dd      001Ch                                           ;54 ds
                        dd      0                                               ;58 fs
                        dd      0                                               ;5c gs
                        dd      EGDTCONSOLELDT                                  ;60 ldt selector in gdt
                        times   128-($-$$) db 0h                                ;zero fill to end of section
;-----------------------------------------------------------------------------------------------------------------------
;
;       Console Message Queue                                                   @disk: 007e00   @mem: 004800
;
;       The console message queue is 2048 bytes of memory organized as a queue of 510 double words (4 bytes each) and
;       two double word values that act as indices. The queue is a FIFO that is fed by the keyboard hardware interrupt
;       handler and consumed by a service routine called from a task. Each queue entry defines an input (keystroke)
;       event.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 conmque                                                 ;console message queue
                        dd      8                                               ;head pointer
                        dd      8                                               ;tail pointer
                        times   510 dd 0                                        ;queue elements
;-----------------------------------------------------------------------------------------------------------------------
;
;       Console Code                                                            @disk: 008600   @mem: 005000
;
;       This is the code for the console task. The task is defined in the GDT in two descriptors, the Local Descriptor
;       Table (LDT) at 0050h and the Task State Segment (TSS) at 0058h. Jumping to or calling a TSS selector causes a
;       task switch, giving control to the code for the task at the CS:IP defined in the TSS for the current ring level.
;       The initial CS:IP in the Console TSS is 24h:0, where 24h is a selector in the LDT. This selector points to the
;       concode section, loaded into memory 5000h by the Loader. The console task is dedicated to accepting user key-
;       board input, echoing to the console screen and responding to user commands.
;
;       When control reaches this section, our addressability is set up according to the following diagram.
;
;       DS,ES --------> 000000  +-----------------------------------------------+ DS,ES:0000
;                               |  Real Mode Interrupt Vectors                  |
;                       000400  +-----------------------------------------------+ DS,ES:0400
;                               |  Reserved BIOS Memory Area                    |
;                       000800  +-----------------------------------------------+ DS,ES:0800
;                               |  Shared Kernel Memory Area                    |
;                       001000  +-----------------------------------------------+               <-- GDTR
;                               |  Global Descriptor Table (GDT)                |
;                       001800  +-----------------------------------------------+               <-- IDTR
;                               |  Interrupt Descriptor Table (IDT)             |
;                       002000  +-----------------------------------------------+
;                               |  Interrupt Handlers                           |
;                               |  Kernel Function Library                      |
;       SS -----------> 004000  +===============================================+ SS:0000
;                               |  Console Task Stack Area                      |
;       SS:SP --------> 004700  +-----------------------------------------------+ SS:0700       <-- LDTR = GDT.SEL 0050h
;                               |  Console Task Local Descriptor Table (LDT)    |
;                       004780  +-----------------------------------------------+               <-- TR  = GDT.SEL 0058h
;                               |  Console Task Task State Segment (TSS)        |
;                       004800  +-----------------------------------------------+
;                               |  Console Task Message Queue                   |
;       CS,CS:IP -----> 005000  +-----------------------------------------------+ CS:0000
;                               |  Console Task Code                            |
;                               |  Console Task Constants                       |
;                       006000  +===============================================+
;
;-----------------------------------------------------------------------------------------------------------------------
section                 concode vstart=05000h                                   ;labels relative to 5000h
ConCode                 call    ConInitializeData                               ;initialize console variables

                        clearConsoleScreen                                      ;clear the console screen
                        putConsoleString czTitle                                ;display startup message
                        putConsoleString czROMMem                               ;ROM memory label
                        putConsoleString wzROMMemSize                           ;ROM memory amount
                        putConsoleString czKB                                   ;Kilobytes
                        putConsoleString czNewLine                              ;new line
                        putConsoleString czBaseMem                              ;base memory label
                        putConsoleString wzBaseMemSize                          ;base memory size
                        putConsoleString czKB                                   ;Kilobytes
                        putConsoleString czNewLine                              ;new line
                        putConsoleString czExtendedMem                          ;extended memory label
                        putConsoleString wzExtendedMemSize                      ;extended memory size
                        putConsoleString czKB                                   ;Kilobytes
                        putConsoleString czNewLine                              ;new line
.10                     putConsoleString czPrompt                               ;display input prompt
                        placeCursor                                             ;set CRT cursor location
                        getConsoleString wzConsoleInBuffer,79,1,13              ;accept keyboard input
                        putConsoleString czNewLine                              ;newline

                        mov     edx,wzConsoleInBuffer                           ;console input buffer
                        mov     ebx,wzConsoleToken                              ;token buffer
                        call    ConTakeToken                                    ;handle console input
                        mov     edx,wzConsoleToken                              ;token buffer
                        call    ConDetermineCommand                             ;determine command number
                        cmp     eax,ECONJMPTBLCNT                               ;valid command number?
                        jb      .20                                             ;yes, branch

                        putConsoleString czUnknownCommand                       ;display error message

                        jmp     .10                                             ;next command
.20                     shl     eax,2                                           ;index into jump table
                        mov     edx,tConJmpTbl                                  ;jump table base address
                        mov     eax,[edx+eax]                                   ;command handler routine address
                        call    eax                                             ;call command handler
                        jmp     .10                                             ;next command
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConInitializeData
;
;       Description:    This routine initializes console task variables.
;
;-----------------------------------------------------------------------------------------------------------------------
ConInitializeData       push    ecx                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    es                                              ;
;
;       Initialize console work areas.
;
                        push    EGDTOSDATA                                      ;load OS data selector ...
                        pop     es                                              ;... into extra segment register
                        mov     edi,ECONDATA                                    ;OS console data address
                        xor     al,al                                           ;initialization value
                        mov     ecx,ECONDATALEN                                 ;size of OS console data
                        cld                                                     ;forward strings
                        rep     stosb                                           ;initialize data
;
;       Initialize heap size
;
                        mov     eax,EKRNHEAPSIZE                                ;heap size
                        mov     [wdConsoleHeapSize],eax                         ;set heap size
;
;       Initialize MEMROOT structure
;
                        mov     edi,wsConsoleMemRoot                            ;memory root structure address
                        mov     eax,EKRNHEAPBASE                                ;base address of heap storage
                        xor     ecx,ecx                                         ;zero register
                        mov     cl,4                                            ;count
                        rep     stosd                                           ;store first/last contig and free addrs
                        xor     eax,eax                                         ;zero register
                        stosd                                                   ;zero first task block
                        stosd                                                   ;zero last task block
;
;       Initialize MEMBLOCK structure at EMEMBASE
;
                        mov     edi,EKRNHEAPBASE                                ;memory block structure address
                        mov     eax,EMEMFREECODE                                ;free memory signature
                        stosd                                                   ;store signature
                        mov     eax,EKRNHEAPSIZE                                ;heap size
                        stosd                                                   ;store block size
                        xor     ecx,ecx                                         ;zero register
                        mov     cl,6                                            ;count
                        xor     eax,eax                                         ;zero register
                        rep     stosd                                           ;zero owner, reserved, pointers
;
;       Read memory sizes from ROM
;
                        getROMMemSize                                           ;get ROM memory size
                        mov     [wdROMMemSize],eax                              ;bytes reported by ROM
                        mov     ecx,eax                                         ;integer param
                        mov     edx,wzROMMemSize                                ;output buffer param
                        mov     bh,3                                            ;no leading zeros; thousands grouping
                        unsignedToDecimalString                                 ;build ASCIIZ decimal string
                        getBaseMemSize                                          ;get base RAM count from CMOS
                        mov     [wdBaseMemSize],eax                             ;save base RAM count
                        mov     ecx,eax                                         ;integer param
                        mov     edx,wzBaseMemSize                               ;output buffer param
                        mov     bh,3                                            ;no leading zeros; thousands grouping
                        unsignedToDecimalString                                 ;build ASCIIZ decimal string
                        getExtendedMemSize                                      ;get extended RAM count from CMOS
                        mov     [wdExtendedMemSize],eax                         ;save base RAM count
                        mov     ecx,eax                                         ;integer param
                        mov     edx,wzExtendedMemSize                           ;output buffer param
                        mov     bh,3                                            ;no leading zeros; thousands grouping
                        unsignedToDecimalString                                 ;build ASCIIZ decimal string
;
;       Restore and return.
;
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConTakeToken
;
;       Description:    This routine extracts the next token from the given source buffer.
;
;       In:             DS:EDX  source buffer address
;                       DS:EBX  target buffer address
;
;       Out:            DS:EDX  source buffer address
;                       DS:EBX  target buffer address
;
;       Command Form:   Line    = *3( *SP 1*ALNUM )
;
;-----------------------------------------------------------------------------------------------------------------------
ConTakeToken            push    esi                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    es                                              ;
                        push    ds                                              ;load data segment selector ...
                        pop     es                                              ;... into extra segment reg
                        mov     esi,edx                                         ;source buffer address
                        mov     edi,ebx                                         ;target buffer address
                        mov     byte [edi],0                                    ;null-terminate target buffer
                        cld                                                     ;forward strings
.10                     lodsb                                                   ;load byte
                        cmp     al,EASCIISPACE                                  ;space?
                        je      .10                                             ;yes, continue
                        test    al,al                                           ;end of line?
                        jz      .40                                             ;yes, branch
.20                     stosb                                                   ;store byte
                        lodsb                                                   ;load byte
                        test    al,al                                           ;end of line?
                        jz      .40                                             ;no, continue
                        cmp     al,EASCIISPACE                                  ;space?
                        jne     .20                                             ;no, continue
.30                     lodsb                                                   ;load byte
                        cmp     al,EASCIISPACE                                  ;space?
                        je      .30                                             ;yes, continue
                        dec     esi                                             ;pre-position
.40                     mov     byte [edi],0                                    ;terminate buffer
                        mov     edi,edx                                         ;source buffer address
.50                     lodsb                                                   ;remaining byte
                        stosb                                                   ;move to front of buffer
                        test    al,al                                           ;end of line?
                        jnz     .50                                             ;no, continue
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     esi                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConDetermineCommand
;
;       Description:    This routine determines the command number for the command at DS:EDX.
;
;       input:          DS:EDX  command address
;
;       output:         EAX     >=0     = command nbr
;                               0       = unknown command
;
;-----------------------------------------------------------------------------------------------------------------------
ConDetermineCommand     push    ebx                                             ;save non-volatile regs
                        push    ecx                                             ;
                        push    esi                                             ;
                        push    edi                                             ;

                        upperCaseString                                         ;upper-case string at EDX

                        mov     esi,tConCmdTbl                                  ;commands table
                        xor     edi,edi                                         ;intialize command number
                        cld                                                     ;forward strings
.10                     lodsb                                                   ;command length
                        movzx   ecx,al                                          ;command length
                        jecxz   .20                                             ;branch if end of table
                        mov     ebx,esi                                         ;table entry address
                        add     esi,ecx                                         ;next table entry address

                        compareMemory                                           ;compare byte arrays at EDX, EBX

                        jecxz   .20                                             ;branch if equal
                        inc     edi                                             ;increment command nbr
                        jmp     .10                                             ;repeat
.20                     mov     eax,edi                                         ;command number
                        pop     edi                                             ;restore non-volatile regs
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        pop     ebx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConClear
;
;       Description:    This routine handles the CLEAR command and its CLS alias.
;
;-----------------------------------------------------------------------------------------------------------------------
ConClear                clearConsoleScreen                                      ;clear console screen
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConDate
;
;       Description:    This routine handles the DATE command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConDate                 readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        putDateString     wsConsoleDateTime,wzConsoleOutBuffer  ;format date string
                        putConsoleString  wzConsoleOutBuffer                    ;write string to console
                        putConsoleString  czNewLine                             ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConDay
;
;       Description:    This routine handles the DAY command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConDay                  readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        putDayString      wsConsoleDateTime,wzConsoleOutBuffer  ;format day string
                        putConsoleString  wzConsoleOutBuffer                    ;write string to console
                        putConsoleString  czNewLine                             ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConExit
;
;       Description:    This routine handles the EXIT command and its SHUTDOWN and QUIT aliases.
;
;-----------------------------------------------------------------------------------------------------------------------
ConExit                 resetSystem                                             ;issue system reset
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConFree
;
;       Description:    This routine handles the FREE command.
;
;       Input:          wzConsoleInBuffer contains parameter(s)
;
;-----------------------------------------------------------------------------------------------------------------------
ConFree                 push    ebx                                             ;save non-volatile regs
                        push    ecx                                             ;
                        push    esi                                             ;
                        push    edi                                             ;
;
;       Get address parameter
;
                        mov     edx,wzConsoleInBuffer                           ;console input buffer address (param)
                        mov     ebx,wzConsoleToken                              ;console command token address
                        call    ConTakeToken                                    ;take first param as token
;
;       Convert input parameter from hexadecimal string to binary
;
                        cmp     byte [wzConsoleToken],0                         ;token found?
                        je      .10                                             ;no, branch
                        mov     edx,wzConsoleToken                              ;first param as token address

                        hexadecimalToUnsigned                                   ;convert string token to unsigned

                        test    eax,eax                                         ;valid parameter?
                        jz      .10                                             ;no, branch
;
;       Free memory block
;
                        freeMemory eax                                          ;free memory

                        cmp     eax,-1                                          ;memory freed?
                        je      .10                                             ;no, branch
;
;       Indicate memory freed
;
                        putConsoleString czOK                                   ;indicate success
;
;       Restore and return
;
.10                     pop     edi                                             ;restore non-volatile regs
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        pop     ebx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConHour
;
;       Description:    This routine Handles the HOUR command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConHour                 readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        putHourString     wsConsoleDateTime,wzConsoleOutBuffer  ;format hour string
                        putConsoleString  wzConsoleOutBuffer                    ;write string to console
                        putConsoleString  czNewLine                             ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConInt6
;
;       Description:    This routine issues an interrupt 6 to exercise the interrupt handler.
;
;-----------------------------------------------------------------------------------------------------------------------
ConInt6                 ud2                                                     ;raise bad opcode exception
                        ret                                                     ;return (not executed)
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConMalloc
;
;       Description:    This routine handles the MALLOC command.
;
;       Input:          wzConsoleInBuffer contains parameter(s)
;
;-----------------------------------------------------------------------------------------------------------------------
ConMalloc               push    ebx                                             ;save non-volatile regs
                        push    ecx                                             ;
                        push    esi                                             ;
                        push    edi                                             ;
;
;       Get size parameter
;
                        mov     edx,wzConsoleInBuffer                           ;console input buffer address (params)
                        mov     ebx,wzConsoleToken                              ;console command token address
                        call    ConTakeToken                                    ;take first param as token
;
;       Convert input parameter from decimal string to binary
;
                        cmp     byte [wzConsoleToken],0                         ;token found?
                        je      .10                                             ;no, branch
                        mov     edx,wzConsoleToken                              ;first param as token address

                        decimalToUnsigned                                       ;convert string token to unsigned

                        test    eax,eax                                         ;valid parameter?
                        jz      .10                                             ;no, branch
;
;       Allocate memory block
;
                        allocateMemory eax                                      ;allocate memory

                        test    eax,eax                                         ;memory allocated?
                        jz      .10                                             ;no, branch
;
;       Report allocated memory block address
;
                        mov     edx,wzConsoleOutBuffer                          ;output buffer address
                        mov     ecx,eax                                         ;memory address

                        unsignedToHexadecimal                                   ;convert memory address to hex
                        putConsoleString wzConsoleOutBuffer                     ;display memory address
                        putConsoleString czNewLine                              ;display new line

.10                     pop     edi                                             ;restore non-volatile regs
                        pop     esi                                             ;
                        pop     ecx                                             ;
                        pop     ebx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConMem
;
;       Description:    This routine handles the MEMORY command and its MEM alias.
;
;       Input:          wzConsoleInBuffer contains parameter(s)
;
;-----------------------------------------------------------------------------------------------------------------------
ConMem                  push    ebx                                             ;save non-volatile regs
                        push    esi                                             ;
                        push    edi                                             ;
;
;                       update the source address if a parameter is given
;
                        mov     edx,wzConsoleInBuffer                           ;console input buffer address (params)
                        mov     ebx,wzConsoleToken                              ;console command token address
                        call    ConTakeToken                                    ;take first param as token
                        cmp     byte [wzConsoleToken],0                         ;token found?
                        je      .10                                             ;no, branch
                        mov     edx,wzConsoleToken                              ;first param as token address

                        hexadecimalToUnsigned                                   ;convert string token to unsigned

                        mov     [wdConsoleMemBase],eax                          ;save console memory address
;
;                       setup source address and row count
;
.10                     mov     esi,[wdConsoleMemBase]                          ;source memory address
                        xor     ecx,ecx                                         ;zero register
                        mov     cl,16                                           ;row count
;
;                       start the row with the source address in hexadecimal
;
.20                     push    ecx                                             ;save remaining rows
                        mov     edi,wzConsoleOutBuffer                          ;output buffer address
                        mov     edx,edi                                         ;output buffer address
                        mov     ecx,esi                                         ;console memory address

                        unsignedToHexadecimal                                   ;convert unsigned address to hex string

                        add     edi,8                                           ;end of memory addr hexnum
                        mov     al,' '                                          ;ascii space
                        stosb                                                   ;store delimiter
;
;                       output 16 ASCII hexadecimal byte values for the row
;
                        xor     ecx,ecx                                         ;zero register
                        mov     cl,16                                           ;loop count
.30                     push    ecx                                             ;save loop count
                        lodsb                                                   ;memory byte
                        mov     ah,al                                           ;memory byte
                        shr     al,4                                            ;high-order in bits 3-0
                        or      al,30h                                          ;apply ascii numeric zone
                        cmp     al,3ah                                          ;numeric range?
                        jb      .40                                             ;yes, skip ahead
                        add     al,7                                            ;adjust ascii for 'A'-'F'
.40                     stosb                                                   ;store ascii hexadecimal of high-order
                        mov     al,ah                                           ;low-order in bits 3-0
                        and     al,0fh                                          ;mask out high-order bits
                        or      al,30h                                          ;apply ascii numeric zone
                        cmp     al,3ah                                          ;numeric range?
                        jb      .50                                             ;yes, skip ahead
                        add     al,7                                            ;adjust ascii for 'A'-'F'
.50                     stosb                                                   ;store ascii hexadecimal of low-order
                        mov     al,' '                                          ;ascii space
                        stosb                                                   ;store ascii space delimiter
                        pop     ecx                                             ;loop count
                        loop    .30                                             ;next
;
;                       output printable ASCII character section for the row
;
                        sub     esi,16                                          ;reset source pointer
                        mov     cl,16                                           ;loop count
.60                     lodsb                                                   ;source byte
                        cmp     al,32                                           ;printable? (low-range test)
                        jb      .70                                             ;no, skip ahead
                        cmp     al,128                                          ;printable? (high-range test)
                        jb      .80                                             ;yes, skip ahead
.70                     mov     al,' '                                          ;display space instead of printable
.80                     stosb                                                   ;store printable ascii byte
                        loop    .60                                             ;next source byte
                        xor     al,al                                           ;nul-terminator
                        stosb                                                   ;terminate output line
;
;                       display constructed output buffer and newline
;
                        putConsoleString wzConsoleOutBuffer                     ;display constructed output
                        putConsoleString czNewLine                              ;display new line
;
;                       repeat until all lines displayed and preserve source address
;
                        pop     ecx                                             ;remaining rows
                        loop    .20                                             ;next row
                        mov     [wdConsoleMemBase],esi                          ;update console memory address
                        pop     edi                                             ;restore regs
                        pop     esi                                             ;
                        pop     ebx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConMinute
;
;       Description:    This routine Handles the MINUTE command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConMinute               readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        putMinuteString   wsConsoleDateTime,wzConsoleOutBuffer  ;format minute string
                        putConsoleString  wzConsoleOutBuffer                    ;write string to console
                        putConsoleString  czNewLine                             ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConMonth
;
;       Description:    This routine Handles the MONTH command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConMonth                readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        putMonthString    wsConsoleDateTime,wzConsoleOutBuffer  ;format month string
                        putConsoleString  wzConsoleOutBuffer                    ;write string to console
                        putConsoleString  czNewLine                             ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConMonthName
;
;       Description:    This routine Handles the MONTH.NAME command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConMonthName            readRealTimeClock  wsConsoleDateTime                    ;read RTC data into structure
                        putMonthNameString wsConsoleDateTime,wzConsoleOutBuffer ;format month name string
                        putConsoleString   wzConsoleOutBuffer                   ;write string to console
                        putConsoleString   czNewLine                            ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConPCIProbe
;
;       Description:    This routine handles the PCIProbe command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConPCIProbe             push    ebx                                             ;save non-volatile regs
;
;                       initialize variables
;
                        xor     al,al                                           ;zero register
                        mov     [wbConsolePCIBus],al                            ;initialize bus
                        mov     [wbConsolePCIDevice],al                         ;initialize device
                        mov     [wbConsolePCIFunction],al                       ;initialize function
;
;                       construct PCI selector
;
.10                     mov     ah,[wbConsolePCIBus]                            ;AH = bbbb bbbb
                        mov     dl,[wbConsolePCIDevice]                         ;DL = ???d dddd
                        shl     dl,3                                            ;DL = dddd d000
                        mov     al,[wbConsolePCIFunction]                       ;AL = ???? ?fff
                        and     al,007h                                         ;AL = 0000 0fff
                        or      al,dl                                           ;AL = dddd dfff
                        movzx   eax,ax                                          ;0000 0000 0000 0000 bbbb bbbb dddd dfff
                        shl     eax,8                                           ;0000 0000 bbbb bbbb dddd dfff 0000 0000
                        or      eax,80000000h                                   ;1000 0000 bbbb bbbb dddd dfff 0000 0000
                        mov     [wdConsolePCISelector],eax                      ;save selector
;
;                       read PCI data register
;
                        mov     dx,0cf8h                                        ;register port
                        out     dx,eax                                          ;select device
                        mov     dx,0cfch                                        ;data port
                        in      eax,dx                                          ;read register data
                        mov     [wdConsolePCIData],eax                          ;save data
;
;                       interpret PCI data value and display finding
;
                        cmp     eax,0ffffffffh                                  ;not defined?
                        je      .20                                             ;yes, branch
                        mov     edx,wzConsoleToken                              ;output buffer
                        call    ConBuildPCIIdent                                ;build PCI bus, device, function ident

                        putConsoleString wzConsoleToken                         ;display bus as decimal

                        call    ConInterpretPCIData                             ;update flags based on data

                        putConsoleString czSpace
                        putConsoleString [wdConsolePCIVendorStr]
                        putConsoleString czSpace
                        putConsoleString [wdConsolePCIChipStr]
                        putConsoleString czNewLine                              ;display new line
;
;                       step to next function, device, bus
;
.20                     inc     byte [wbConsolePCIFunction]                     ;next function
                        cmp     byte [wbConsolePCIFunction],8                   ;at limit?
                        jb      .10                                             ;no, continue
                        mov     byte [wbConsolePCIFunction],0                   ;zero function
                        inc     byte [wbConsolePCIDevice]                       ;next device
                        cmp     byte [wbConsolePCIDevice],32                    ;at limit?
                        jb      .10                                             ;no, continue
                        mov     byte [wbConsolePCIDevice],0                     ;zero device
                        inc     byte [wbConsolePCIBus]                          ;next bus
                        cmp     byte [wbConsolePCIBus],0                        ;at limit?
                        jb      .10                                             ;no, continue

                        jmp     .30

;
;                       report if ethernet adapter found
;
                        test    byte [wbConsoleHWFlags],EHWETHERNET             ;ethernet h/w switch set?
                        jz      .30                                             ;branch if no

                        putConsoleString czEthernetAdapterFound                 ;report adapter found
;
;                       read base address register 0 at offset 10h
;
                        mov     eax,[wdConsoleEthernetDevice]                   ;adapter PCI selector
                        or      eax,10h                                         ;set function bits
                        mov     dx,0cf8h                                        ;register port
                        out     dx,eax                                          ;select register
                        mov     dx,0cfch                                        ;data port
                        in      eax,dx                                          ;register data
                        mov     [wdConsoleEthernetMem],eax                      ;save ethernet memory mapped i/o addr
;
;                       report base address register 0 value
;
                        mov     ecx,eax                                         ;unsigned integer param
                        mov     edx,wzConsoleToken                              ;target buffer address

                        unsignedToHexadecimal                                   ;convert unsigned to ASCII hex string
                        putConsoleString wzConsoleToken                         ;output string to console
                        putConsoleString czNewLine                              ;output newline to console
;
;                       read base address register 2 at offset 18h
;
                        mov     eax,[wdConsoleEthernetDevice]                   ;adapter PCI selector
                        or      eax,18h                                         ;set function bits
                        mov     dx,0cf8h                                        ;register port
                        out     dx,eax                                          ;select register
                        mov     dx,0cfch                                        ;data port
                        in      eax,dx                                          ;register data
                        and     al,0feh                                         ;clear bit zero
                        mov     [wdConsoleEthernetPort],eax                     ;save ethernet i/o port
;
;                       report base address register 2 value
;
                        mov     ecx,eax                                         ;unsigned integer param
                        mov     edx,wzConsoleToken                              ;target buffer address

                        unsignedToHexadecimal                                   ;convert unsigned to ASCII hex string
                        putConsoleString wzConsoleToken                         ;output string to console
                        putConsoleString czNewLine                              ;output newline to console
;
;                       read ethernet control register using port i/o
;
                        mov     eax,[wdConsoleEthernetPort]                     ;ethernet i/o port
                        mov     dx,ax                                           ;ethernet i/o port
                        xor     eax,eax                                         ;control register (zero)
                        out     dx,eax                                          ;select register
                        add     dx,4                                            ;data register
                        in      eax,dx                                          ;read register data
                        mov     [wdConsoleEthernetCtrl],eax                     ;save ethernet control register value
;
;                       report adapter control register value
;
                        mov     ecx,eax                                         ;unsigned integer param
                        mov     edx,wzConsoleToken                              ;target buffer address

                        unsignedToHexadecimal                                   ;convert unsigned to ASCII hex string
                        putConsoleString wzConsoleToken                         ;output string to console
                        putConsoleString czNewLine                              ;output newline to console

.30                     pop     ebx                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConBuildPCIIdent
;
;       Description:    This routine constructs a PCI identification string from the current PCI Bus, Device, and
;                       Function code values.
;
;       In:             DS:EDX  output buffer address
;
;-----------------------------------------------------------------------------------------------------------------------
ConBuildPCIIdent        push    edi                                             ;save non-volatile regs
                        mov     edi,edx                                         ;output buffer address
                        mov     al,[wbConsolePCIBus]                            ;current PCI bus (0-255)
                        xor     ah,ah                                           ;zero high-order dividend
                        mov     cl,100                                          ;divisor (10^2)
                        div     cl                                              ;AL=100's, AH=bus MOD 100
                        or      al,30h                                          ;apply ASCII zone
                        cld                                                     ;forward strings
                        stosb                                                   ;store 100's digit
                        mov     al,ah                                           ;bus MOD 100
                        xor     ah,ah                                           ;zero high-order dividend
                        mov     cl,10                                           ;divisor (10^1)
                        div     cl                                              ;AL=10's, AH=1's
                        or      ax,3030h                                        ;apply ASCII zone
                        stosw                                                   ;store 10's and 1's
                        mov     al,EASCIIPERIOD                                 ;ASCII period delimiter
                        stosb                                                   ;store delimiter
                        mov     al,[wbConsolePCIDevice]                         ;current PCI device (0-15)
                        xor     ah,ah                                           ;zero high order dividend
                        mov     cl,10                                           ;divisor (10^1)
                        div     cl                                              ;AL=10's, AH=1's
                        or      ax,3030h                                        ;apply ASCII zone
                        stosw                                                   ;store 10's and 1's
                        mov     al,EASCIIPERIOD                                 ;ASCII period delimiter
                        stosb                                                   ;store delimiter
                        mov     al,[wbConsolePCIFunction]                       ;current PCI function (0-7)
                        or      al,30h                                          ;apply ASCII zone
                        stosb                                                   ;store 1's
                        xor     al,al                                           ;null terminator
                        stosb                                                   ;store terminator
                        pop     edi                                             ;restore non-volatile regs
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConInterpretPCIData
;
;       Description:    This routine interprets the PCI vendor and device IDs.
;
;-----------------------------------------------------------------------------------------------------------------------
ConInterpretPCIData     mov     eax,czApple
                        cmp     word [wwConsolePCIVendor],EPCIVENDORAPPLE       ;Apple?
                        jne     .10                                             ;no, branch
                        mov     edx,czUSBController
                        cmp     word [wwConsolePCIChip],EPCIAPPLEUSB            ;USB?
                        je      .80                                             ;yes, branch
                        mov     edx,czOther                                     ;other
                        jmp     .80                                             ;continue
.10                     mov     eax,czIntel                                     ;Intel
                        cmp     word [wwConsolePCIVendor],EPCIVENDORINTEL       ;Intel?
                        jne     .20                                             ;no, branch
                        mov     edx,czPro1000MT                                 ;Pro/1000 MT
                        cmp     word [wwConsolePCIChip],EPCIINTELPRO1000MT      ;Pro/1000 MT?
                        je      .80                                             ;yes, branch
                        mov     edx,czPCIAndMem                                 ;PCI and Memory
                        cmp     word [wwConsolePCIChip],EPCIINTELPCIMEM         ;PCI and Memory?
                        je      .80                                             ;yes, branch
                        mov     edx,czAurealAD1881                              ;Aureal 1881 SOUNDMAX
                        cmp     word [wwConsolePCIChip],EPCIINTELAD1881         ;Aureal 1881 SOUNDMAX?
                        je      .80                                             ;yes, branch
                        mov     edx,czPIIX3PCItoIDEBridge                       ;PIIX3 PCI-to-IDE Bridge
                        cmp     word [wwConsolePCIChip],EPCIINTELPIIX3          ;PIIX3 PCI-to-IDE Bridge?
                        je      .80                                             ;yes, branch
                        mov     edx,cz82371ABBusMaster                          ;82371AB Bus Master
                        cmp     word [wwConsolePCIChip],EPCIINTEL82371AB        ;82371AB Bus Master?
                        je      .80                                             ;yes, branch
                        mov     edx,czPIIX4PowerMgmt                            ;PIIX4/4E/4M Power Mgmt Controller
                        cmp     word [wwConsolePCIChip],EPCIINTELPIIX4          ;PIIX4/4E/4M Power Mgmt Controller?
                        je      .80                                             ;yes, branch
                        mov     edx,czOther                                     ;other
                        jmp     .80                                             ;continue
.20                     mov     eax,czOracle                                    ;Oracle
                        cmp     word [wwConsolePCIVendor],EPCIVENDORORACLE      ;Oracle?
                        jne     .30                                             ;no, branch
                        mov     edx,czVirtualBoxGA                              ;VirtulaBox Graphics Adapter
                        cmp     word [wwConsolePCIChip],EPCIORACLEVBOXGA        ;VirtualBox Graphics Adapter?
                        je      .80                                             ;yes, branch
                        mov     edx,czVirtualBoxDevice                          ;VirtualBox Device
                        cmp     word [wwConsolePCIChip],EPCIORACLEVBOXDEVICE    ;VirtualBox Device?
                        je      .80                                             ;yes, branch
                        mov     edx,czOther                                     ;other
                        jmp     .80                                             ;continue
.30                     mov     eax,czOther                                     ;other
                        mov     edx,czOther                                     ;other
.80                     mov     [wdConsolePCIVendorStr],eax                     ;save vendor string
                        mov     [wdConsolePCIChipStr],edx                       ;save chip string
                        cmp     word [wwConsolePCIChip],EPCIINTELPRO1000MT      ;Pro/1000 MT Ethernet Adapter
                        jne     .90                                             ;no, branch
                        or      byte [wbConsoleHWFlags],EHWETHERNET             ;ethernet adapter found
                        mov     eax,[wdConsolePCISelector]                      ;PCI selector
                        mov     [wdConsoleEthernetDevice],eax                   ;save as ethernet device selector
.90                     ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConSecond
;
;       Description:    This routine Handles the SECOND command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConSecond               readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        putSecondString   wsConsoleDateTime,wzConsoleOutBuffer  ;format second string
                        putConsoleString  wzConsoleOutBuffer                    ;write string to console
                        putConsoleString  czNewLine                             ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConTime
;
;       Description:    This routine Handles the TIME command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConTime                 readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        putTimeString     wsConsoleDateTime,wzConsoleOutBuffer  ;format time string
                        putConsoleString  wzConsoleOutBuffer                    ;write string to console
                        putConsoleString  czNewLine                             ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConVersion
;
;       Description:    This routine handles the VERSION command and its alias, VER.
;
;-----------------------------------------------------------------------------------------------------------------------
ConVersion              putConsoleString czTitle                                ;display version message
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConWeekday
;
;       Description:    This routine handles the WEEKDAY command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConWeekday              readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        putWeekdayString  wsConsoleDateTime,wzConsoleOutBuffer  ;format weekday string
                        putConsoleString  wzConsoleOutBuffer                    ;write string to console
                        putConsoleString  czNewLine                             ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConWeekdayName
;
;       Description:    This routine Handles the WEEKDAY.NAME command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConWeekdayName          readRealTimeClock    wsConsoleDateTime                          ;read RTC data into structure
                        putWeekdayNameString wsConsoleDateTime,wzConsoleOutBuffer       ;format day name string
                        putConsoleString     wzConsoleOutBuffer                         ;write string to console
                        putConsoleString     czNewLine                                  ;write newline to console
                        ret                                                             ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConYear
;
;       Description:    This routine Handles the YEAR command.
;
;-----------------------------------------------------------------------------------------------------------------------
ConYear                 readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        putYearString     wsConsoleDateTime,wzConsoleOutBuffer  ;format year string
                        putConsoleString  wzConsoleOutBuffer                    ;write string to console
                        putConsoleString  czNewLine                             ;write newline to console
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        ConYearIsLeap
;
;       Description:    This routine handles the YEAR.ISLEAP command
;
;-----------------------------------------------------------------------------------------------------------------------
ConYearIsLeap           readRealTimeClock wsConsoleDateTime                     ;read RTC data into structure
                        isLeapYear        wsConsoleDateTime                     ;indicate if year is leap year

                        jecxz   .10                                             ;branch if not leap

                        putConsoleString  czYearIsLeap                          ;display year is leap message

                        jmp     .20                                             ;continue

.10                     putConsoleString  czYearIsNotLeap                       ;display year is not leap mesage
.20                     ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Tables
;
;-----------------------------------------------------------------------------------------------------------------------
                                                                                ;---------------------------------------
                                                                                ;  Command Jump Table
                                                                                ;---------------------------------------
tConJmpTbl              equ     $                                               ;command jump table
                        dd      ConWeekdayName  - ConCode                       ;weekday.name command routine offset
                        dd      ConYearIsLeap   - ConCode                       ;year.isleap command routine offset
                        dd      ConMonthName    - ConCode                       ;month.name command routine offset
                        dd      ConPCIProbe     - ConCode                       ;pciprobe command routine offset
                        dd      ConExit         - ConCode                       ;shutdown command routine offset
                        dd      ConVersion      - ConCode                       ;version command routine offset
                        dd      ConWeekday      - ConCode                       ;weekday command routine offset
                        dd      ConMalloc       - ConCode                       ;malloc command routine offset
                        dd      ConMem          - ConCode                       ;memory command routine offset
                        dd      ConMinute       - ConCode                       ;minute command routine offset
                        dd      ConSecond       - ConCode                       ;second command routine offset
                        dd      ConClear        - ConCode                       ;clear command routine offset
                        dd      ConPCIProbe     - ConCode                       ;lspci command routine offset
                        dd      ConMonth        - ConCode                       ;month command routine offset
                        dd      ConDate         - ConCode                       ;date command routine offset
                        dd      ConExit         - ConCode                       ;exit command routine offset
                        dd      ConFree         - ConCode                       ;free command routine offset
                        dd      ConHour         - ConCode                       ;hour command routine offset
                        dd      ConInt6         - ConCode                       ;int6 command routine offset
                        dd      ConExit         - ConCode                       ;quit command routine offset
                        dd      ConTime         - ConCode                       ;time command routine offset
                        dd      ConYear         - ConCode                       ;year command routine offset
                        dd      ConClear        - ConCode                       ;cls command routine offset
                        dd      ConDay          - ConCode                       ;day command routine offset
                        dd      ConMem          - ConCode                       ;mem command routine offset
                        dd      ConVersion      - ConCode                       ;ver command routine offset
ECONJMPTBLL             equ     ($-tConJmpTbl)                                  ;table length
ECONJMPTBLCNT           equ     ECONJMPTBLL/4                                   ;table entries
                                                                                ;---------------------------------------
                                                                                ;  Command Name Table
                                                                                ;---------------------------------------
tConCmdTbl              equ     $                                               ;command name table
                        db      13,"WEEKDAY.NAME",0                             ;weekday.name command
                        db      12,"YEAR.ISLEAP",0                              ;year.isleap command
                        db      11,"MONTH.NAME",0                               ;month.name command
                        db      9,"PCIPROBE",0                                  ;pciprobe command
                        db      9,"SHUTDOWN",0                                  ;shutdown command
                        db      8,"VERSION",0                                   ;version command
                        db      8,"WEEKDAY",0                                   ;weekday command
                        db      7,"MALLOC",0                                    ;malloc command
                        db      7,"MEMORY",0                                    ;memory command
                        db      7,"MINUTE",0                                    ;minute command
                        db      7,"SECOND",0                                    ;second command
                        db      6,"CLEAR",0                                     ;clear command
                        db      6,"LSPCI",0                                     ;lspci command (pciprobe alias)
                        db      6,"MONTH",0                                     ;month command
                        db      5,"DATE",0                                      ;date command
                        db      5,"EXIT",0                                      ;exit command
                        db      5,"FREE",0                                      ;free command
                        db      5,"HOUR",0                                      ;hour command
                        db      5,"INT6",0                                      ;int6 command
                        db      5,"QUIT",0                                      ;quit command
                        db      5,"TIME",0                                      ;time command
                        db      5,"YEAR",0                                      ;year command
                        db      4,"CLS",0                                       ;cls command
                        db      4,"DAY",0                                       ;day command
                        db      4,"MEM",0                                       ;mem command
                        db      4,"VER",0                                       ;ver command
                        db      0                                               ;end of table
;-----------------------------------------------------------------------------------------------------------------------
;
;       Constants
;
;-----------------------------------------------------------------------------------------------------------------------
czApple                 db      "Apple",0                                       ;vendor name string
czAurealAD1881          db      "Aureal AD1881 SOUNDMAX",0                      ;soundmax string
czBaseMem               db      "Base memory: ",0                               ;base memory from BIOS
czEthernetAdapterFound  db      "Ethernet adapter found",13,10,0                ;adapter found message
czExtendedMem           db      "Extended memory: ",0                           ;extended memory from BIOS
czIntel                 db      "Intel",0                                       ;vendor name string
czKB                    db      "KB",0                                          ;Kilobytes
czNewLine               db      13,10,0                                         ;new line string
czOK                    db      "ok",13,10,0                                    ;ok string
czOracle                db      "Oracle",0                                      ;vendor name string
czOther                 db      "Other",0                                       ;default name string
czPCIAndMem             db      "PCI & Memory",0                                ;PCI and Memory string
czPeriod                db      ".",0                                           ;period delimiter
czPIIX3PCItoIDEBridge   db      "PIIX3 PCI-to-ISA Bridge",0                     ;pci-to-isa bridge string
czPIIX4PowerMgmt        db      "PIIX4/4E/4M Power Management Controller",0     ;power management controller string
czPrompt                db      ":",0                                           ;prompt string
czPro1000MT             db      "Pro/1000 MT Ethernet Adapter",0                ;Intel Pro/1000 MT Ethernet adapter strg
czROMMem                db      "Base memory below EBDA (Int 12h): ",0          ;memory reported by ROM
czSpace                 db      " ",0                                           ;space delimiter
czTitle                 db      "Custom Operating System 1.0",13,10,0           ;version string
czUnknownCommand        db      "Unknown command",13,10,0                       ;unknown command response string
czUSBController         db      "USB Controller",0                              ;USB controller string
czVirtualBoxDevice      db      "VirtualBox Device",0                           ;Virtual Box device string
czVirtualBoxGA          db      "VirtualBox Graphics Adapter",0                 ;Virtual Box graphics adapter string
czYearIsLeap            db      "The year is a leap year.",13,10,0              ;leap year message
czYearIsNotLeap         db      "The year is not a leap year.",13,10,0          ;not leap year message
cz82371ABBusMaster      db      "82371AB/EB PCI Bus Master IDE Controller",0    ;bus-master strin
                        times   4096-($-$$) db 0h                               ;zero fill to end of section
;=======================================================================================================================
;
;       Background Task                                                         @disk: 009600   @mem: 006000
;
;       This task executes monitoring and self-correcting functions.
;
;                       000000  +-----------------------------------------------+
;                               |  Real Mode Interrupt Vectors                  |
;                       000400  +-----------------------------------------------+ DS,ES:0400
;                               |  Reserved BIOS Memory Area                    |
;                       000800  +-----------------------------------------------+ DS,ES:0800
;                               |  Shared Kernel Memory Area                    |
;                       001000  +-----------------------------------------------+               <-- GDTR
;                               |  Global Descriptor Table (GDT)                |
;                       001800  +-----------------------------------------------+               <-- IDTR
;                               |  Interrupt Descriptor Table (IDT)             |
;                       002000  +-----------------------------------------------+
;                               |  Interrupt Handlers                           |
;                               |  Kernel Function Library                      |
;                       004000  +===============================================+
;                               |  Console Task Stack Area                      |
;                       004700  +-----------------------------------------------+
;                               |  Console Task Local Descriptor Table (LDT)    |
;                       004780  +-----------------------------------------------+
;                               |  Console Task Task State Segment (TSS)        |
;                       004800  +-----------------------------------------------+
;                               |  Console Task Message Queue                   |
;                       005000  +-----------------------------------------------+
;                               |  Console Task Code                            |
;                               |  Console Task Constants                       |
;                       006000  +===============================================+
;                               |  Background Task Stack Area                   |
;       SS:SP --------> 006700  +-----------------------------------------------+ SS:0700       <-- LDTR = GDT.SEL 0060h
;                               |  Background Task Local Descriptor Table (LDT) |
;                       006780  +-----------------------------------------------+               <-- TR = GDT.SEL 0068h
;                               |  Background Task Task State Segment (TSS)     |
;                       006800  +-----------------------------------------------+
;                               |  Background Task Message Queue                |
;       CS,CS:IP -----> 007000  +-----------------------------------------------+ CS:0000
;                               |  Background Task Code                         |
;                               |  Background Task Constants                    |
;                       008000  +===============================================+
;
;=======================================================================================================================
;-----------------------------------------------------------------------------------------------------------------------
;
;       Background Task Stack                                                   @disk: 009600   @mem:  006000
;
;       This is the stack for the background task. It supports 448 nested calls.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 bgstack                                                 ;background task stack
                        times   1792-($-$$) db 0h                               ;zero fill to end of section
;-----------------------------------------------------------------------------------------------------------------------
;
;       Background Task Local Descriptor Table                                  @disk: 009D00   @mem:  006700
;
;       This is the LDT for the background task. It defines the stack, code, data and queue segments as well as data
;       aliases for the TSS LDT. Data aliases allow inspection and altering of the TSS and LDT. This LDT can hold up to
;       16 descriptors. Six are initially defined.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 bgldt                                                   ;background task local descriptors
                        dq      004093006780007Fh                               ;04 TSS alias           128B  @ 6780
                        dq      004093006700007Fh                               ;0C LDT alias           128B  @ 6700
                        dq      00409300600006FFh                               ;14 stack               1792B @ 6600
                        dq      00CF93000000FFFFh                               ;1C data                4GB   @ 0000
                        dq      00409B0070000FFFh                               ;24 code                4KB   @ 7000
                        dq      00409300680007FFh                               ;2C message queue       2KB   @ 6800
                        times   128-($-$$) db 0h                                ;zero fill to end of section
;-----------------------------------------------------------------------------------------------------------------------
;
;       Background Task State Segment                                           @disk: 009D80   @mem:  006780
;
;       This is the TSS for the console task. All rings share the same stack. DS and ES are set to the console data
;       segment. CS to console code.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 bgtss                                                   ;background task state segment
                        dd      0                                               ;00 back-link tss
                        dd      0700h                                           ;04 esp ring 0
                        dd      0014h                                           ;08 ss ring 0
                        dd      0700h                                           ;0C esp ring 1
                        dd      0014h                                           ;10 es ring 1
                        dd      0700h                                           ;14 esp ring 2
                        dd      0014h                                           ;18 ss ring 2
                        dd      0                                               ;1C cr ring 3
                        dd      0                                               ;20 eip
                        dd      0200h                                           ;24 eflags
                        dd      0                                               ;28 eax
                        dd      0                                               ;2C ecx
                        dd      0                                               ;30 edx
                        dd      0                                               ;34 ebx
                        dd      0700h                                           ;38 esp ring 3
                        dd      0                                               ;3C ebp
                        dd      0                                               ;40 esi
                        dd      0                                               ;44 edi
                        dd      001Ch                                           ;48 es
                        dd      0024h                                           ;4C cs
                        dd      0014h                                           ;50 ss ring 3
                        dd      001Ch                                           ;54 ds
                        dd      0                                               ;58 fs
                        dd      0                                               ;5c gs
                        dd      ESELBACKGROUNDLDT                               ;60 ldt selector in gdt
                        times   128-($-$$) db 0h                                ;zero fill to end of section
;-----------------------------------------------------------------------------------------------------------------------
;
;       Background Task Message Queue                                           @disk: 009E00   @mem: 006800
;
;       The console message queue is 2048 bytes of memory organized as a queue of 510 double words (4 bytes each) and
;       two double word values that act as indices. The queue is a FIFO that is fed by the keyboard hardware interrupt
;       handler and consumed by a service routine called from a task. Each queue entry defines an input (keystroke)
;       event.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 bgmque                                                  ;console message queue
                        dd      8                                               ;head pointer
                        dd      8                                               ;tail pointer
                        times   510 dd 0                                        ;queue elements
;-----------------------------------------------------------------------------------------------------------------------
;
;       Background Task Code                                                    @disk: 00A600   @mem: 007000
;
;-----------------------------------------------------------------------------------------------------------------------
section                 bgcode  vstart=07000h                                   ;labels relative to 7000h
BackgroundCode          call    BgInitializeData                                ;initialize the background variables

.10                     readRealTimeClock wsBgDateTime                          ;read real-time clock data
                        putTimeString     wsBgDateTime,wzBgTime                 ;create ASCII time string
                        compareMemory     wzBgTime,wzBgTimeCmpr,EBGTIMELEN      ;compare to previous time string

                        jecxz   .10                                             ;repeat if equal
                        push    es                                              ;save non-volatile reg
                        push    EGDTCGA                                         ;load CGA selector ...
                        pop     es                                              ;... into extra segment reg
                        mov     esi,wzBgTime                                    ;string address
                        mov     ch,24                                           ;OIA row
                        mov     cl,67                                           ;OIA column

                        setConsoleString                                        ;display string

                        pop     es                                              ;restore non-volatile reg

                        copyMemory        wzBgTime,wzBgTimeCmpr,EBGTIMELEN      ;copy to comparison string
                        yield                                                   ;halt until interrupt

                        jmp     .10                                             ;continue
;-----------------------------------------------------------------------------------------------------------------------
;
;       Routine:        BgInitializeData
;
;       Description:    This routine initializes background task variables.
;
;-----------------------------------------------------------------------------------------------------------------------
BgInitializeData        push    ecx                                             ;save non-volatile regs
                        push    edi                                             ;
                        push    es                                              ;
;
;       Initialize console work areas
;
                        push    EGDTOSDATA                                      ;load OS data selector ...
                        pop     es                                              ;... into extra segment register
                        mov     edi,EBGDATA                                     ;OS console data address
                        xor     al,al                                           ;initialization value
                        mov     ecx,EBGDATALEN                                  ;size of OS console data
                        cld                                                     ;forward strings
                        rep     stosb                                           ;initialize data
;
;       Restore and return
;
                        pop     es                                              ;restore non-volatile regs
                        pop     edi                                             ;
                        pop     ecx                                             ;
                        ret                                                     ;return
;-----------------------------------------------------------------------------------------------------------------------
;
;       Background Task Constants
;
;-----------------------------------------------------------------------------------------------------------------------
                        times   4096-($-$$) db 0h                               ;zero fill to end of section
%endif
%ifdef BUILDDISK
;-----------------------------------------------------------------------------------------------------------------------
;
;       Free Disk Space                                                         @disk: 00B600   @mem:  n/a
;
;       Following the convention introduced by DOS, we use the value 'F6' to indicate unused floppy disk storage.
;
;-----------------------------------------------------------------------------------------------------------------------
section                 unused                                                  ;unused disk space
                        times   EBOOTDISKBYTES-0B600h db 0F6h                   ;fill to end of disk image
%endif
;=======================================================================================================================
;
;       End of Program Code
;
;=======================================================================================================================