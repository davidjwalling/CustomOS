��CustomOS  � @�	     �  X��!����Ã��ێÎӼ ����& ����؃��?� ����K������&��6��������&��������� ��;�v��)����>�VW� ��_^t>�Hu����>� u����� ������� �Z �E�=P�����0�������9 �0��&�X��������Ѓ�ǁ� ���t���%�=�u�� ���&����������6�ģ�� SQ�������Y[sC���0���00��:r��<:r������� ��u�������d��������t����Ð  OS      COMLoading OS
 Disk error    OS missing �                 U�������u����<t<u�� �n���� �� Q�v�  � ��Ys�쾞�,�v��� ��� �� Q� �  � ��Ys&���P�� ���00��:r��<:r�D��X�8��< t&��<t��<t�*<t��<t
�
<�t��
���� L�!�
CustomOS Boot-Diskette Preparation Program
Copyright (C) 2010-2017 David J. Walling. All rights reserved.

This program overwrites the boot sector of a diskette with startup code that
will load the operating system into memory when the computer is restarted.
To proceed, place a formatted diskette into drive A: and press the Enter key.
To exit this program without preparing a diskette, press the Escape key.
 
Writing the boot sector to the diskette ...
 
The error-code .. was returned from the BIOS while reading from the disk.
 
The error-code .. was returned from the BIOS while writing to the disk.
 
The boot-sector was written to the diskette. Before booting your computer with
this diskette, make sure that the file OS.COM is copied onto the diskette.
 
(01) Invalid Disk Parameter
This is an internal error caused by an invalid value being passed to a system
function. The OSBOOT.COM file may be corrupt. Copy or download the file again
and retry.
 
(02) Address Mark Not Found
This error indicates a physical problem with the floppy diskette. Please retry
using another diskette.
 
(03) Protected Disk
This error is usually caused by attempting to write to a write-protected disk.
Check the 'write-protect' setting on the disk or retry using using another disk.
 
(06) Diskette Removed
This error may indicate that the floppy diskette has been removed from the
diskette drive. On some systems, this code may also occur if the diskette is
'write protected.' Please verify that the diskette is not write-protected and
is properly inserted in the diskette drive.
 
(80) Drive Timed Out
This error usually indicates that no diskette is in the diskette drive. Please
make sure that the diskette is properly seated in the drive and retry.
 
(??) Unknown Error
The error-code returned by the BIOS is not a recognized error. Please consult
your computer's technical reference for a description of this error code.
 