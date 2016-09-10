;	VirtualDub - Video processing and capture application
;	Copyright (C) 1998-2001 Avery Lee
;
;	This program is free software; you can redistribute it and/or modify
;	it under the terms of the GNU General Public License as published by
;	the Free Software Foundation; either version 2 of the License, or
;	(at your option) any later version.
;
;	This program is distributed in the hope that it will be useful,
;	but WITHOUT ANY WARRANTY; without even the implied warranty of
;	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;	GNU General Public License for more details.
;
;	You should have received a copy of the GNU General Public License
;	along with this program; if not, write to the Free Software
;	Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

.686p
.mmx
.xmm
.model flat

extrn _YUV_Y_table:near
extrn _YUV_U_table:near
extrn _YUV_V_table:near
extrn _YUV_clip_table:near
extrn _YUV_clip_table16:near

_rdata segment para public 'DATA' use32
assume cs:_rdata

public SSE2_80w
SSE2_80w	dq	00080008000800080h, 00080008000800080h
SSE2_Ublucoeff	dq	00081008100810081h, 00081008100810081h
SSE2_Vredcoeff	dq	00066006600660066h, 00066006600660066h
SSE2_Ugrncoeff	dq	0FFE7FFE7FFE7FFE7h, 0FFE7FFE7FFE7FFE7h
SSE2_Vgrncoeff	dq	0FFCCFFCCFFCCFFCCh, 0FFCCFFCCFFCCFFCCh
SSE2_Ylow	dq	000FF00FF00FF00FFh, 000FF00FF00FF00FFh
SSE2_Ybias	dq	00010001000100010h, 00010001000100010h
SSE2_Ycoeff	dq	0004A004A004A004Ah, 0004A004A004A004Ah
SSE2_Ucoeff0	dq	000810000FFE70081h, 0FFE700810000FFE7h
SSE2_Ucoeff1	dq	00000FFE700810000h, 000810000FFE70081h
SSE2_Ucoeff2	dq	0FFE700810000FFE7h, 00000FFE700810000h
SSE2_Vcoeff0	dq	000000066FFCC0000h, 0FFCC00000066FFCCh
SSE2_Vcoeff1	dq	00066FFCC00000066h, 000000066FFCC0000h
SSE2_Vcoeff2	dq	0FFCC00000066FFCCh, 00066FFCC00000066h

MMX_10w		dq	00010001000100010h
MMX_80w		dq	00080008000800080h
MMX_00FFw	dq	000FF00FF00FF00FFh
MMX_FF00w	dq	0FF00FF00FF00FF00h
MMX_Ublucoeff	dq	00081008100810081h
MMX_Vredcoeff	dq	00066006600660066h
MMX_Ugrncoeff	dq	0FFE7FFE7FFE7FFE7h
MMX_Vgrncoeff	dq	0FFCCFFCCFFCCFFCCh
MMX_Ycoeff	dq	0004A004A004A004Ah
MMX_rbmask	dq	07c1f7c1f7c1f7c1fh
MMX_grnmask	dq	003e003e003e003e0h
MMX_grnmask2	dq	000f800f800f800f8h
MMX_clip	dq	07c007c007c007c00h

MMX_Ucoeff0	dq	000810000FFE70081h
MMX_Ucoeff1	dq	0FFE700810000FFE7h
MMX_Ucoeff2	dq	00000FFE700810000h
MMX_Vcoeff0	dq	000000066FFCC0000h
MMX_Vcoeff1	dq	0FFCC00000066FFCCh
MMX_Vcoeff2	dq	00066FFCC00000066h
_rdata ends



_text segment para public 'CODE' use32
assume cs:_text
assume es:nothing, ss:nothing, ds:_rdata, fs:nothing, gs:nothing


;	asm_YUVtoRGB_row(
;		Pixel *ARGB1_pointer,
;		Pixel *ARGB2_pointer,
;		YUVPixel *Y1_pointer,
;		YUVPixel *Y2_pointer,
;		YUVPixel *U_pointer,
;		YUVPixel *V_pointer,
;		long width
;		);

public _asm_YUVtoRGB32_row
_asm_YUVtoRGB32_row proc near

arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

push	ebx
push	esi
push	edi
push	ebp
mov	eax, [esp+10h+arg_18]
mov	ebp, eax
mov	ebx, eax
shl	ebx, 3
add	eax, eax
add	[esp+10h+arg_0], ebx
add	[esp+10h+arg_4], ebx
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp

mov	esi, [esp+10h+arg_10]	;[C]
mov	edi, [esp+10h+arg_14]	;[C]
xor	edx, edx				;[C]
xor	ecx, ecx				;[C]
jmp	short col_loop_start

col_loop:
mov	ch, byte ptr (_YUV_clip_table-3F00h)[ebx]	;[4] edx = [0][0][red][green]
mov	esi, [esp+10h+arg_10]						;[C]
shl	ecx, 8										;[4] edx = [0][red][green][0]
mov	edi, [esp+10h+arg_14]						;[C]
mov	cl, byte ptr (_YUV_clip_table-3F00h)[edx]	;[4] edx = [0][r][g][b] !!
xor	edx, edx									;[C]
mov	[eax+ebp*8-4], ecx							;[4] 
xor	ecx, ecx									;[C]

col_loop_start:
mov	cl, [esi+ebp]								;[C] eax = U
mov	dl, [edi+ebp]								;[C] ebx = V
mov	eax, [esp+10h+arg_8]						;[1] 
xor	ebx, ebx									;[1] 

loc_64:
mov	esi, dword ptr ds:_YUV_U_table[ecx*4]		;[C] eax = [b impact][u-g impact]
mov	ecx, dword ptr ds:_YUV_V_table[edx*4]		;[C] ebx = [r impact][v-g impact]
mov	edi, esi									;[C]
mov	bl, [eax+ebp*2]								;[1] ebx = Y1 value
shr	esi, 10h									;[C] eax = blue impact
add	edi, ecx									;[C] edi = [junk][g impact]
mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]		;[1] ebx = Y impact
and	ecx, 0FFFF0000h								;[C]
mov	edx, ebx									;[1] edx = Y impact
add	esi, ecx									;[C] eax = [r impact][b impact]
and	edi, 0FFFFh									;[C]
add	ebx, esi									;[1] ebx = [red][blue]
mov	ecx, ebx									;[1] edi = [red][blue]
and	edx, 0FFFFh									;[1] ecx = green
shr	ebx, 10h									;[1] ebx = red
and	ecx, 0FFFFh									;[1] edi = blue
mov	dl, byte ptr (_YUV_clip_table-3F00h)[edx+edi]	;[1] edx = [0][0][junk][green]
mov	eax, [esp+10h+arg_8]						;[2] 
mov	dh, byte ptr (_YUV_clip_table-3F00h)[ebx]	;[1] edx = [0][0][red][green]
xor	ebx, ebx									;[2] 
shl	edx, 8										;[1] edx = [0][red][green][0]
mov	bl, [eax+ebp*2+1]							;[2] ebx = Y1 value
mov	eax, [esp+10h+arg_0]						;[1] 
mov	dl, byte ptr (_YUV_clip_table-3F00h)[ecx]	;[1] edx = [0][r][g][b] !!
mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]		;[2] ebx = Y impact
mov	ecx, 0FFFFh									;[2]

and	ecx, ebx									;[2]
add	ebx, esi									;[2] ebx = [red][blue]

mov	[eax+ebp*8], edx							;[1] 
mov	edx, ebx									;[2]

shr	ebx, 10h									;[2] ebx = red
mov	eax, [esp+10h+arg_C]						;[3] 

and	edx, 0FFFFh									;[2]
mov	cl, byte ptr (_YUV_clip_table-3F00h)[ecx+edi]	;[2] edx = [0][0][junk][green]

mov	al, [eax+ebp*2]								;[3] ebx = Y1 value
mov	ch, byte ptr (_YUV_clip_table-3F00h)[ebx]	;[2] edx = [0][0][red][green]

shl	ecx, 8										;[2] edx = [0][red][green][0]
and	eax, 0FFh									;[3] 

mov	cl, byte ptr (_YUV_clip_table-3F00h)[edx]	;[2] edx = [0][r][g][b] !!
mov	edx, [esp+10h+arg_0]						;[2] 

mov	ebx, dword ptr ds:_YUV_Y_table[eax*4]		;[3] ebx = Y impact
mov	eax, 0FFFFh

and	eax, ebx									;[3] edi = [red][blue]
add	ebx, esi									;[3] ebx = [red][blue]

mov	[edx+ebp*8+4], ecx							;[2] 
mov	edx, ebx									;[3]

shr	ebx, 10h									;[3] ebx = red
mov	ecx, [esp+10h+arg_C]						;[4] 

and	edx, 0FFFFh									;[3] ecx = green
mov	al, byte ptr (_YUV_clip_table-3F00h)[eax+edi]	;[3] edx = [0][0][junk][green]

mov	cl, [ecx+ebp*2+1]							;[4] ebx = Y1 value
mov	ah, byte ptr (_YUV_clip_table-3F00h)[ebx]	;[3] edx = [0][0][red][green]

shl	eax, 8										;[3] edx = [0][red][green][0]
and	ecx, 0FFh									;[4] 

mov	al, byte ptr (_YUV_clip_table-3F00h)[edx]	;[3] edx = [0][r][g][b] !!
mov	edx, [esp+10h+arg_4]						;[3] 

mov	ebx, dword ptr ds:_YUV_Y_table[ecx*4]		;[4] ebx = Y impact
mov	ecx, 0FFFFh									;[4]

and	ecx, ebx									;[4] ecx = [0][Y-impact]
add	ebx, esi									;[4] ebx = [red][blue]

mov	[edx+ebp*8], eax							;[3]
mov	edx, ebx									;[4] edx = [red][blue]

shr	ebx, 10h									;[4] ebx = red
mov	cl, byte ptr (_YUV_clip_table-3F00h)[ecx+edi]	;[4] edx = [0][0][junk][green]

and	edx, 0FFFFh									;[4] edx = blue
mov	eax, [esp+10h+arg_4]						;[4] 

inc	ebp

jnz	col_loop

mov	ch, byte ptr (_YUV_clip_table-3F00h)[ebx]	;[4] edx = [0][0][red][green]
shl	ecx, 8										;[4] edx = [0][red][green][0]
mov	cl, byte ptr (_YUV_clip_table-3F00h)[edx]	;[4] edx = [0][r][g][b] !!
mov	[eax+ebp*8-4], ecx							;[4] 

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB32_row endp


;MMX_test	dq	7060504030201000h

public _asm_YUVtoRGB32_row_MMX
_asm_YUVtoRGB32_row_MMX	proc near

arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

push	ebx
push	esi
push	edi
push	ebp
mov	eax, [esp+10h+arg_18]
mov	ebp, eax
mov	ebx, eax
shl	ebx, 3
add	eax, eax
add	[esp+10h+arg_0], ebx
add	[esp+10h+arg_4], ebx
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp

mov	esi, [esp+10h+arg_10]
mov	edi, [esp+10h+arg_14]
mov	ecx, [esp+10h+arg_8]
mov	edx, [esp+10h+arg_C]
mov	eax, [esp+10h+arg_0]
mov	ebx, [esp+10h+arg_4]

col_loop_MMX:
movd	mm0, dword ptr [esi+ebp]	;U (byte)
pxor	mm7, mm7

movd	mm1, dword ptr [edi+ebp]	;V (byte)
punpcklbw mm0, mm7					;U (word)

psubw	mm0, MMX_80w
punpcklbw mm1, mm7					;V (word)

psubw	mm1, MMX_80w
movq	mm2, mm0

pmullw	mm2, MMX_Ugrncoeff
movq	mm3, mm1

pmullw	mm3, MMX_Vgrncoeff
pmullw	mm0, MMX_Ublucoeff
pmullw	mm1, MMX_Vredcoeff
paddw	mm2, mm3

;mm0: blue
;mm1: red
;mm2: green

movq	mm6, qword ptr [ecx+ebp*2]	;Y
pand	mm6, MMX_00FFw
psubw	mm6, MMX_10w
pmullw	mm6, MMX_Ycoeff
movq	mm4, mm6
paddw	mm6, mm0					;mm6: <B3><B2><B1><B0>
movq	mm5, mm4
paddw	mm4, mm1					;mm4: <R3><R2><R1><R0>
paddw	mm5, mm2					;mm5: <G3><G2><G1><G0>
psraw	mm6, 6
psraw	mm4, 6
packuswb mm6, mm6					;mm6: B3B2B1B0B3B2B1B0
psraw	mm5, 6
packuswb mm4, mm4					;mm4: R3R2R1R0R3R2R1R0
punpcklbw mm6, mm4					;mm6: R3B3R2B2R1B1R0B0
packuswb mm5, mm5					;mm5: G3G2G1G0G3G2G1G0
punpcklbw mm5, mm5					;mm5: G3G3G2G2G1G1G0G0
movq	mm4, mm6
punpcklbw mm6, mm5					;mm6: G1R1G1B2G0R0G0B0
punpckhbw mm4, mm5					;mm4: G3R3G3B3G2R2G2B2

movq	mm7, qword ptr [ecx+ebp*2]	;Y
psrlw	mm7, 8
psubw	mm7, MMX_10w
pmullw	mm7, MMX_Ycoeff
movq	mm3, mm7
paddw	mm7, mm0					;mm7: final blue
movq	mm5, mm3
paddw	mm3, mm1					;mm3: final red
paddw	mm5, mm2					;mm5: final green
psraw	mm7, 6
psraw	mm3, 6
packuswb mm7, mm7					;mm7: B3B2B1B0B3B2B1B0
psraw	mm5, 6
packuswb mm3, mm3					;mm3: R3R2R1R0R3R2R1R0
punpcklbw mm7, mm3					;mm7: R3B3R2B2R1B1R0B0
packuswb mm5, mm5					;mm5: G3G2G1G0G3G2G1G0
punpcklbw mm5, mm5					;mm5: G3G3G2G2G1G1G0G0
movq	mm3, mm7
punpcklbw mm7, mm5					;mm7: G1R1G1B2G0R0G0B0
punpckhbw mm3, mm5					;mm3: G3R3G3B3G2R2G2B2

;mm3	P7:P5
;mm4	P6:P4
;mm6	P2:P0
;mm7	P3:P1

movq	mm5, mm6
punpckldq mm5, mm7					;P1:P0
punpckhdq mm6, mm7					;P3:P2
movq	mm7, mm4
punpckldq mm4, mm3					;P5:P4
punpckhdq mm7, mm3					;P7:P6

movq	qword ptr [eax+ebp*8], mm5
movq	qword ptr [eax+ebp*8+8], mm6
movq	qword ptr [eax+ebp*8+10h], mm4
movq	qword ptr [eax+ebp*8+18h], mm7

movq	mm6, qword ptr [edx+ebp*2]	;Y
pand	mm6, MMX_00FFw
psubw	mm6, MMX_10w
pmullw	mm6, MMX_Ycoeff
movq	mm4, mm6
paddw	mm6, mm0					;mm6: <B3><B2><B1><B0>
movq	mm5, mm4
paddw	mm4, mm1					;mm4: <R3><R2><R1><R0>
paddw	mm5, mm2					;mm5: <G3><G2><G1><G0>
psraw	mm6, 6
psraw	mm4, 6
packuswb mm6, mm6					;mm6: B3B2B1B0B3B2B1B0
psraw	mm5, 6
packuswb mm4, mm4					;mm4: R3R2R1R0R3R2R1R0
punpcklbw mm6, mm4					;mm6: R3B3R2B2R1B1R0B0
packuswb mm5, mm5					;mm5: G3G2G1G0G3G2G1G0
punpcklbw mm5, mm5					;mm5: G3G3G2G2G1G1G0G0
movq	mm4, mm6
punpcklbw mm6, mm5					;mm6: G1R1G1B2G0R0G0B0
punpckhbw mm4, mm5					;mm4: G3R3G3B3G2R2G2B2

movq	mm7, qword ptr [edx+ebp*2]	;Y
psrlw	mm7, 8
psubw	mm7, MMX_10w
pmullw	mm7, MMX_Ycoeff
movq	mm3, mm7
paddw	mm7, mm0					;mm7: final blue
movq	mm5, mm3
paddw	mm3, mm1					;mm3: final red
paddw	mm5, mm2					;mm5: final green
psraw	mm7, 6
psraw	mm3, 6
packuswb mm7, mm7					;mm7: B3B2B1B0B3B2B1B0
psraw	mm5, 6
packuswb mm3, mm3					;mm3: R3R2R1R0R3R2R1R0
punpcklbw mm7, mm3					;mm7: R3B3R2B2R1B1R0B0
packuswb mm5, mm5					;mm5: G3G2G1G0G3G2G1G0
punpcklbw mm5, mm5					;mm5: G3G3G2G2G1G1G0G0
movq	mm3, mm7
punpcklbw mm7, mm5					;mm7: G1R1G1B2G0R0G0B0
punpckhbw mm3, mm5					;mm3: G3R3G3B3G2R2G2B2

;mm3	P7:P5
;mm4	P6:P4
;mm6	P2:P0
;mm7	P3:P1

movq	mm5, mm6
punpckldq mm5, mm7					;P1:P0
punpckhdq mm6, mm7					;P3:P2
movq	mm7, mm4
punpckldq mm4, mm3					;P5:P4
punpckhdq mm7, mm3					;P7:P6

movq	qword ptr [ebx+ebp*8], mm5
movq	qword ptr [ebx+ebp*8+8], mm6

movq	qword ptr [ebx+ebp*8+10h], mm4
movq	qword ptr [ebx+ebp*8+18h], mm7

add	ebp, 4

jnz	col_loop_MMX

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB32_row_MMX	endp


;**************************************************************************
;
;	asm_YUVtoRGB24_row(
;		Pixel *ARGB1_pointer,
;		Pixel *ARGB2_pointer,
;		YUVPixel *Y1_pointer,
;		YUVPixel *Y2_pointer,
;		YUVPixel *U_pointer,
;		YUVPixel *V_pointer,
;		long width
;		);

public _asm_YUVtoRGB24_row
_asm_YUVtoRGB24_row proc near

arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

push	ebx
push	esi
push	edi
push	ebp
mov	eax, [esp+10h+arg_18]
mov	ebp, eax
add	eax, eax
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp

mov	esi, [esp+10h+arg_10]					;[C]
mov	edi, [esp+10h+arg_14]					;[C]
xor	edx, edx								;[C]
xor	ecx, ecx								;[C]

col_loop24:
mov	esi, [esp+10h+arg_10]
mov	edi, [esp+10h+arg_14]
xor	eax, eax
xor	ebx, ebx
mov	al, [esi+ebp]							;eax = U
mov	bl, [edi+ebp]							;ebx = V
mov	eax, dword ptr ds:_YUV_U_table[eax*4]	;eax = [b impact][u-g impact]
mov	edi, dword ptr ds:_YUV_V_table[ebx*4]	;edi = [r impact][v-g impact]

mov	ecx, eax								;[C]
mov	esi, [esp+10h+arg_8]					;[1]

mov	edx, edi								;[C]
xor	ebx, ebx								;[1]

shr	eax, 10h								;[C] eax = blue impact
mov	bl, [esi+ebp*2]							;[1] ebx = Y1 value

and	edi, 0FFFF0000h							;[C] edi = [r impact][0]
add	ecx, edx								;[C] ecx = [junk][g impact]

add	eax, edi								;[C] eax = [r impact][b impact]
mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]	;[1] ebx = Y impact

;eax = [r][b]
;ecx = [g]

mov	esi, ebx								;[1]
add	ebx, eax								;[1] ebx = [red][blue]

add	esi, ecx								;[1] edx = [junk][green]
mov	edi, ebx								;[1] edi = [red][blue]

shr	ebx, 10h								;[1] ebx = red
and	esi, 0FFFFh								;[1] ecx = green

and	edi, 0FFFFh								;edi = blue
xor	edx, edx

mov	bh, byte ptr (_YUV_clip_table-3F00h)[ebx]	;bh = red
mov	dl, byte ptr (_YUV_clip_table-3F00h)[esi]	;dl = green

mov	esi, [esp+10h+arg_8]						;[2]
mov	bl, byte ptr (_YUV_clip_table-3F00h)[edi]	;bl = blue

mov	edi, [esp+10h+arg_0]					;[1]
											;[1]
mov	[edi+2], bh
mov	[edi], bl								;[1]
											;[2]
xor	ebx, ebx
mov	[edi+1], dl								;[1]

mov	bl, [esi+ebp*2+1]						;[2] ebx = Y1 value
mov	esi, ecx								;[2]

mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]	;[2] ebx = Y impact
mov	edi, 0FFFFh								;[2]

add	esi, ebx								;[2] edx = [junk][green]
add	ebx, eax								;[2] ebx = [red][blue]

and	edi, ebx								;[2] edi = blue
and	esi, 0FFFFh								;[2] ecx = green

shr	ebx, 10h								;ebx = red
xor	edx, edx

mov	bh, byte ptr (_YUV_clip_table-3F00h)[ebx]	;bh = red
mov	dl, byte ptr (_YUV_clip_table-3F00h)[esi]	;dl = green

mov	esi, [esp+10h+arg_C]						;[3]
mov	bl, byte ptr (_YUV_clip_table-3F00h)[edi]	;bl = blue

mov	edi, [esp+10h+arg_0]					;[2]
mov	[edi+5], bh								;[2]

mov	[edi+4], dl								;[2]
mov	[edi+3], bl								;[2]

xor	ebx, ebx								;[3]

mov	bl, [esi+ebp*2]							;[3] ebx = Y1 value
mov	edi, ecx								;[2]

mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]	;[3] ebx = Y impact
mov	esi, 0FFFFh								;[3]

add	edi, ebx								;[3] edx = [junk][green]
add	ebx, eax								;[3] ebx = [red][blue]

and	esi, ebx								;[3] edi = blue
and	edi, 0FFFFh								;ecx = green

shr	ebx, 10h								;ebx = red
xor	edx, edx

mov	dl, byte ptr (_YUV_clip_table-3F00h)[edi]	;dl = green
mov	edi, [esp+10h+arg_4]						;[3]

mov	bh, byte ptr (_YUV_clip_table-3F00h)[ebx]	;bh = red
mov	bl, byte ptr (_YUV_clip_table-3F00h)[esi]	;bl = blue

mov	esi, [esp+10h+arg_C]					;[4]
mov	[edi+2], bh

mov	[edi], bl
xor	ebx, ebx								;[4]

mov	[edi+1], dl
mov	bl, [esi+ebp*2+1]						;[4] ebx = Y1 value

mov	edi, 0FFFFh								;[4]

mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]	;[4] ebx = Y impact
xor	edx, edx

add	ecx, ebx								;[4] ecx = [junk][green]
add	ebx, eax								;ebx = [red][blue]

and	edi, ebx								;edi = blue
and	ecx, 0FFFFh								;ecx = green

shr	ebx, 10h								;ebx = red
mov	esi, [esp+10h+arg_4]

mov	bl, byte ptr (_YUV_clip_table-3F00h)[ebx]	;bh = red
mov	dl, byte ptr (_YUV_clip_table-3F00h)[ecx]	;dl = green

mov	al, byte ptr (_YUV_clip_table-3F00h)[edi]	;bl = blue
mov	[esi+5], bl

mov	[esi+4], dl
mov	ecx, [esp+10h+arg_0]

mov	[esi+3], al
add	esi, 6

mov	[esp+10h+arg_4], esi
add	ecx, 6

mov	[esp+10h+arg_0], ecx

inc	ebp
jnz	col_loop24

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB24_row endp




public _asm_YUVtoRGB24_row_MMX
_asm_YUVtoRGB24_row_MMX	proc near

arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

push	ebx
push	esi
push	edi
push	ebp
mov	eax, [esp+10h+arg_18]
mov	ebp, eax
add	eax, eax
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp
mov	esi, [esp+10h+arg_10]
mov	edi, [esp+10h+arg_14]
mov	ecx, [esp+10h+arg_8]
mov	edx, [esp+10h+arg_C]
mov	eax, [esp+10h+arg_0]
mov	ebx, [esp+10h+arg_4]

col_loop_MMX24:
movd	mm0, dword ptr [esi+ebp]		;U (byte)
pxor	mm7, mm7

movd	mm1, dword ptr [edi+ebp]		;V (byte)
punpcklbw mm0, mm7						;U (word)

movd	mm2, dword ptr [ecx+ebp*2]		;Y low
punpcklbw mm1, mm7						;V (word)

movd	mm3, dword ptr [edx+ebp*2]		;Y high
punpcklbw mm2, mm7						;Y1 (word)

psubw	mm2, MMX_10w
punpcklbw mm3, mm7						;Y2 (word)

psubw	mm3, MMX_10w

psubw	mm0, MMX_80w
psubw	mm1, MMX_80w

;group 1

pmullw	mm2, MMX_Ycoeff					;[lazy]
movq	mm6, mm0
pmullw	mm3, MMX_Ycoeff					;[lazy]
movq	mm7, mm1
punpcklwd mm6, mm6						;mm6 = U1U1U0U0
movq	mm4, mm2						;mm4 = Y3Y2Y1Y0		[high]
punpckldq mm6, mm6						;mm6 = U0U0U0U0
movq	mm5, mm3						;mm5 = Y3Y2Y1Y0		[low]
punpcklwd mm7, mm7						;mm7 = V1V1V0V0
punpckldq mm7, mm7						;mm7 = V0V0V0V0

pmullw	mm6, MMX_Ucoeff0
punpcklwd mm4, mm4						;mm4 = Y1Y1Y0Y0		[high]
pmullw	mm7, MMX_Vcoeff0
punpcklwd mm5, mm5						;mm5 = Y1Y1Y0Y0		[low]

punpcklwd mm4, mm2						;mm4 = Y1Y0Y0Y0
punpcklwd mm5, mm3						;mm5 = Y1Y0Y0Y0

paddw	mm4, mm6
paddw	mm5, mm6
paddw	mm4, mm7
paddw	mm5, mm7

psraw	mm4, 6
psraw	mm5, 6

packuswb mm4, mm4
packuswb mm5, mm5

;group 2

movd	dword ptr [eax], mm4			;[lazy write]
movq	mm4, mm0
movd	dword ptr [ebx], mm5			;[lazy write]
movq	mm5, mm1

punpcklwd mm4, mm4						;mm4 = U1U1U0U0
movq	mm6, mm2						;mm6 = Y3Y2Y1Y0		[high]
punpcklwd mm5, mm5						;mm5 = V1V1V0V0
movq	mm7, mm3						;mm7 = Y3Y2Y1Y0		[low]

pmullw	mm4, MMX_Ucoeff1
psrlq	mm6, 10h						;mm6 = 00Y3Y2Y1		[high]
pmullw	mm5, MMX_Vcoeff1
psrlq	mm7, 10h						;mm7 = 00Y3Y2Y1		[low]

punpcklwd mm6, mm6						;mm6 = Y2Y2Y1Y1		[high]
punpcklwd mm7, mm7						;mm7 = Y2Y2Y1Y1		[high]

paddw	mm6, mm4
paddw	mm7, mm4
paddw	mm6, mm5
paddw	mm7, mm5

psraw	mm6, 6
psraw	mm7, 6

packuswb mm6, mm6
packuswb mm7, mm7

; group 3

movd	dword ptr [eax+4], mm6			;[lazy write]
movq	mm6, mm0
movd	dword ptr [ebx+4], mm7			;[lazy write]
movq	mm7, mm1

movq	mm4, mm2						;mm4 = Y3Y2Y1Y0		[high]
punpcklwd mm6, mm6						;mm6 = U1U1U0U0
movq	mm5, mm3						;mm5 = Y3Y2Y1Y0		[low]
punpckhdq mm6, mm6						;mm6 = U1U1U1U1
punpcklwd mm7, mm7						;mm7 = V1V1V0V0
punpckhdq mm7, mm7						;mm7 = V1V1V1V1

pmullw	mm6, MMX_Ucoeff2
punpckhwd mm2, mm2						;mm2 = Y3Y3Y2Y2		[high]
pmullw	mm7, MMX_Vcoeff2
punpckhwd mm3, mm3						;mm3 = Y3Y3Y2Y2		[low]

punpckhdq mm4, mm2						;mm4 = Y3Y3Y3Y2		[high]
punpckhdq mm5, mm3						;mm5 = Y3Y3Y3Y2		[low]

paddw	mm4, mm6
paddw	mm5, mm6
paddw	mm4, mm7
paddw	mm5, mm7

psraw	mm4, 6
psraw	mm5, 6

; next 3 groups

movd	mm2, dword ptr [ecx+ebp*2+4]	;Y low
packuswb mm4, mm4

movd	mm3, dword ptr [edx+ebp*2+4]	;Y high
packuswb mm5, mm5

movd	dword ptr [eax+8], mm4			;[lazy write]
pxor	mm7, mm7

movd	dword ptr [ebx+8], mm5			;[lazy write]
punpcklbw mm2, mm7						;U (word)

psubw	mm2, MMX_10w
punpcklbw mm3, mm7
										;V (word)
psubw	mm3, MMX_10w

;group 1

pmullw	mm2, MMX_Ycoeff					;[init]
movq	mm6, mm0

pmullw	mm3, MMX_Ycoeff					;[init]
punpckhwd mm6, mm6						;mm6 = U3U3U2U2

movq	mm7, mm1
punpckldq mm6, mm6						;mm6 = U2U2U2U2
movq	mm4, mm2						;mm4 = Y3Y2Y1Y0		[high]
punpckhwd mm7, mm7						;mm7 = V3V3V2V2
movq	mm5, mm3						;mm5 = Y3Y2Y1Y0		[low]
punpckldq mm7, mm7						;mm7 = V2V2V2V2

pmullw	mm6, MMX_Ucoeff0
punpcklwd mm4, mm4						;mm4 = Y1Y1Y0Y0		[high]
pmullw	mm7, MMX_Vcoeff0
punpcklwd mm5, mm5						;mm5 = Y1Y1Y0Y0		[low]

punpcklwd mm4, mm2						;mm4 = Y1Y0Y0Y0
punpcklwd mm5, mm3						;mm5 = Y1Y0Y0Y0

paddw	mm4, mm6
paddw	mm5, mm6
paddw	mm4, mm7
paddw	mm5, mm7

psraw	mm4, 6
psraw	mm5, 6

packuswb mm4, mm4
packuswb mm5, mm5

; group 2

movd	dword ptr [eax+0Ch], mm4
movq	mm6, mm0
movd	dword ptr [ebx+0Ch], mm5
movq	mm7, mm1

punpckhwd mm6, mm6						;mm6 = U3U3U2U2
movq	mm4, mm2						;mm4 = Y3Y2Y1Y0		[high]
punpckhwd mm7, mm7						;mm7 = V3V3V2V2
movq	mm5, mm3						;mm5 = Y3Y2Y1Y0		[low]

pmullw	mm6, MMX_Ucoeff1
psrlq	mm4, 10h						;mm4 = 00Y3Y2Y1		[high]
pmullw	mm7, MMX_Vcoeff1
psrlq	mm5, 10h						;mm5 = 00Y3Y2Y1		[low]

punpcklwd mm4, mm4						;mm4 = Y2Y2Y1Y1		[high]
punpcklwd mm5, mm5						;mm5 = Y2Y2Y1Y1		[high]

paddw	mm4, mm6
paddw	mm5, mm6
paddw	mm4, mm7
paddw	mm5, mm7

psraw	mm4, 6
psraw	mm5, 6

packuswb mm4, mm4
packuswb mm5, mm5

; group 3

movq	mm6, mm2					;mm6 = Y3Y2Y1Y0		[high]
punpckhwd mm0, mm0					;mm0 = U3U3U2U2

movq	mm7, mm3					;mm7 = Y3Y2Y1Y0		[low]
punpckhdq mm0, mm0					;mm0 = U3U3U3U3

movd	dword ptr [eax+10h], mm4	;[lazy write]
punpckhwd mm1, mm1					;mm1 = V3V3V2V2

movd	dword ptr [ebx+10h], mm5	;[lazy write]
punpckhdq mm1, mm1					;mm1 = V3V3V3V3

pmullw	mm0, MMX_Ucoeff2
punpckhwd mm2, mm2					;mm2 = Y3Y3Y2Y2		[high]
pmullw	mm1, MMX_Vcoeff2
punpckhwd mm3, mm3					;mm3 = Y3Y3Y2Y2		[low]

punpckhdq mm6, mm2					;mm6 = Y3Y3Y3Y2		[high]
punpckhdq mm7, mm3					;mm7 = Y3Y3Y3Y2		[low]

paddw	mm6, mm0
paddw	mm7, mm0
paddw	mm6, mm1
paddw	mm7, mm1

psraw	mm6, 6
psraw	mm7, 6

packuswb mm6, mm6
packuswb mm7, mm7

movd	dword ptr [eax+14h], mm6
add	eax, 18h
movd	dword ptr [ebx+14h], mm7
add	ebx, 18h

;done

add	ebp, 4
jnz	col_loop_MMX24

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB24_row_MMX	endp

;**************************************************************************

public _asm_YUVtoRGB16_row
_asm_YUVtoRGB16_row proc near

arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

push	ebx
push	esi
push	edi
push	ebp
mov	eax, [esp+10h+arg_18]
mov	ebp, eax
mov	ebx, eax
shl	ebx, 2
add	[esp+10h+arg_0], ebx
add	[esp+10h+arg_4], ebx
add	eax, eax
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp

mov	esi, [esp+10h+arg_10]					;[C]
mov	edi, [esp+10h+arg_14]					;[C]
xor	edx, edx								;[C]
xor	ecx, ecx								;[C]

col_loop16:
mov	esi, [esp+10h+arg_10]
mov	edi, [esp+10h+arg_14]
xor	eax, eax
xor	ebx, ebx
mov	al, [esi+ebp]							;eax = U
mov	bl, [edi+ebp]							;ebx = V
mov	eax, dword ptr ds:_YUV_U_table[eax*4]	;eax = [b impact][u-g impact]
mov	edi, dword ptr ds:_YUV_V_table[ebx*4]	;edi = [r impact][v-g impact]

mov	ecx, eax								;[C]
mov	esi, [esp+10h+arg_8]					;[1]

mov	edx, edi								;[C]
xor	ebx, ebx								;[1]

shr	eax, 10h								;[C] eax = blue impact
mov	bl, [esi+ebp*2]							;[1] ebx = Y1 value

and	edi, 0FFFF0000h							;[C] edi = [r impact][0]
add	ecx, edx								;[C] ecx = [junk][g impact]

add	eax, edi								;[C] eax = [r impact][b impact]
mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]	;[1] ebx = Y impact

;eax = [r][b]
;ecx = [g]

mov	esi, ebx								;[1]
add	ebx, eax								;[1] ebx = [red][blue]

add	esi, ecx								;[1] edx = [junk][green]
mov	edi, ebx								;[1] edi = [red][blue]

shr	ebx, 10h								;[1] ebx = red
and	esi, 0FFFFh								;[1] ecx = green

and	edi, 0FFFFh								;edi = blue
xor	edx, edx

mov	bh, byte ptr (_YUV_clip_table16-3F00h)[ebx]	;bh = red
mov	dl, byte ptr (_YUV_clip_table16-3F00h)[esi]	;dl = green

mov	bl, byte ptr (_YUV_clip_table16-3F00h)[edi]	;bl = blue
xor	dh, dh										;[1]

shl	bh, 2									;[1]
mov	edi, [esp+10h+arg_0]					;[1]

shl	edx, 5									;[1]
mov	esi, [esp+10h+arg_8]					;[2]

add	edx, ebx								;[1]
xor	ebx, ebx								;[2]

mov	[edi+ebp*4], dl							;[1]
mov	bl, [esi+ebp*2+1]						;[2] ebx = Y1 value

mov	[edi+ebp*4+1], dh						;[1]
mov	esi, ecx								;[2]

mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]	;[2] ebx = Y impact
mov	edi, 0FFFFh

add	esi, ebx								;[2] edx = [junk][green]
add	ebx, eax								;[2] ebx = [red][blue]

and	edi, ebx								;[2] edi = blue
and	esi, 0FFFFh								;[2] ecx = green

shr	ebx, 10h								;ebx = red
xor	edx, edx

mov	bh, byte ptr (_YUV_clip_table16-3F00h)[ebx]	;bh = red

mov	dl, byte ptr (_YUV_clip_table16-3F00h)[esi]	;dl = green
mov	bl, byte ptr (_YUV_clip_table16-3F00h)[edi]	;bl = blue

shl	edx, 5									;[2]
mov	edi, [esp+10h+arg_0]					;[2]

shl	bh, 2									;[2]
mov	esi, [esp+10h+arg_C]					;[3]

add	edx, ebx								;[2]
xor	ebx, ebx								;[3]

mov	[edi+ebp*4+2], dl						;[2]
mov	bl, [esi+ebp*2]							;[3] ebx = Y1 value

mov	[edi+ebp*4+3], dh						;[2]
mov	edi, ecx								;[2]

mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]	;[3] ebx = Y impact
mov	esi, 0FFFFh								;[3]

add	edi, ebx								;[3] edx = [junk][green]
add	ebx, eax								;[3] ebx = [red][blue]

and	esi, ebx								;[3] edi = blue
and	edi, 0FFFFh								;ecx = green

shr	ebx, 10h								;ebx = red
xor	edx, edx

mov	dl, byte ptr (_YUV_clip_table16-3F00h)[edi]	;dl = green
mov	edi, [esp+10h+arg_4]						;[3]

shl	edx, 5
mov	bh, byte ptr (_YUV_clip_table16-3F00h)[ebx]	;bh = red

mov	bl, byte ptr (_YUV_clip_table16-3F00h)[esi]	;bl = blue
mov	esi, [esp+10h+arg_C]					;[4]

shl	bh, 2									;[3]
nop

add	edx, ebx								;[3]
xor	ebx, ebx								;[4]

mov	[edi+ebp*4], dl							;[3]
mov	bl, [esi+ebp*2+1]						;[4] ebx = Y1 value

mov	[edi+ebp*4+1], dh						;[3]
mov	edi, 0FFFFh								;[4]

mov	ebx, dword ptr ds:_YUV_Y_table[ebx*4]	;[4] ebx = Y impact
xor	edx, edx

add	ecx, ebx								;[4] ecx = [junk][green]
add	ebx, eax								;ebx = [red][blue]

and	edi, ebx								;edi = blue
and	ecx, 0FFFFh								;ecx = green

shr	ebx, 10h								;ebx = red
mov	esi, [esp+10h+arg_4]

mov	dl, byte ptr (_YUV_clip_table16-3F00h)[ecx]	;dl = green
mov	al, byte ptr (_YUV_clip_table16-3F00h)[edi]	;bl = blue

shl	edx, 5
mov	ah, byte ptr (_YUV_clip_table16-3F00h)[ebx]	;bh = red

shl	ah, 2

add	eax, edx

mov	[esi+ebp*4+2], al
mov	[esi+ebp*4+3], ah

inc	ebp
jnz	col_loop16

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB16_row endp




public _asm_YUVtoRGB16_row_MMX
_asm_YUVtoRGB16_row_MMX	proc near

arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

push	ebx
push	esi
push	edi
push	ebp
mov	eax, [esp+10h+arg_18]
mov	ebp, eax
mov	ebx, eax
shl	ebx, 2
add	eax, eax
add	[esp+10h+arg_0], ebx
add	[esp+10h+arg_4], ebx
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp

mov	esi, [esp+10h+arg_10]
mov	edi, [esp+10h+arg_14]
mov	ecx, [esp+10h+arg_8]
mov	edx, [esp+10h+arg_C]
mov	eax, [esp+10h+arg_0]
mov	ebx, [esp+10h+arg_4]

col_loop_MMX16:
movd	mm0, dword ptr [esi+ebp]		;[0       ] U (byte)
pxor	mm7, mm7						;[0      7] 

movd	mm1, dword ptr [edi+ebp]		;[01     7] V (byte)
punpcklbw mm0, mm7						;[01     7] U (word)

psubw	mm0, MMX_80w					;[01     7] 
punpcklbw mm1, mm7						;[01     7] V (word)

psubw	mm1, MMX_80w					;[01      ] 
movq	mm2, mm0						;[012     ] 

pmullw	mm2, MMX_Ugrncoeff				;[012     ] 
movq	mm3, mm1						;[0123    ] 

;mm0: blue
;mm1: red
;mm2: green

movq	mm6, qword ptr [ecx+ebp*2]		;[0123  6 ] [1] Y
;<-->

pmullw	mm3, MMX_Vgrncoeff				;[0123    ] 
movq	mm7, mm6						;[012   67] [2] Y

pmullw	mm0, MMX_Ublucoeff				;[0123    ] 
psrlw	mm7, 8							;[012   67] [2]

pmullw	mm1, MMX_Vredcoeff				;[0123    ] 
;<-->

pand	mm6, MMX_00FFw					;[012   67] [1]
paddw	mm2, mm3						;[012   6 ] [C]

psubw	mm6, MMX_10w					;[012   67] [1]

pmullw	mm6, MMX_Ycoeff					;[012   67] [1]

psubw	mm7, MMX_10w					;[012   67] [2]
movq	mm4, mm6						;[012 4 67] [1]

pmullw	mm7, MMX_Ycoeff					;[012   67] [2]
movq	mm5, mm6						;[012 4567] [1]

paddw	mm6, mm0						;[012 4 67] [1] mm6: <B3><B2><B1><B0>
paddw	mm4, mm1						;[012 4567] [1] mm4: <R3><R2><R1><R0>

paddw	mm5, mm2						;[012 4567] [1] mm5: <G3><G2><G1><G0>
psraw	mm4, 6							;[012 4567] [1]

movq	mm3, mm7						;[01234567] [2]
psraw	mm5, 4							;[01234567] [1]

paddw	mm7, mm0						;[01234567] [2] mm6: <B3><B2><B1><B0>
psraw	mm6, 6							;[01234567] [1]

paddsw	mm5, MMX_clip
packuswb mm6, mm6						;[01234567] [1] mm6: B3B2B1B0B3B2B1B0

psubusw	mm5, MMX_clip
packuswb mm4, mm4						;[01234567] [1] mm4: R3R2R1R0R3R2R1R0

pand	mm5, MMX_grnmask				;[01234567] [1] mm7: <G3><G2><G1><G0>
psrlq	mm6, 2							;[01234567] [1]

punpcklbw mm6, mm4						;[0123 567] [1] mm4: R3B3R2B2R1B1R0B0

movq	mm4, qword ptr [edx+ebp*2]		;[01234567] [3] Y
psrlw	mm6, 1							;[01234567] [1]

pand	mm6, MMX_rbmask					;[01234567] [1] mm6: <RB3><RB2><RB1><RB0>

por	mm6, mm5							;[01234 67] [1] mm6: P6P4P2P0
movq	mm5, mm3						;[01234567] [2]

paddw	mm3, mm1						;[01234567] [2] mm4: <R3><R2><R1><R0>
paddw	mm5, mm2						;[01234567] [2] mm5: <G3><G2><G1><G0>

pand	mm4, MMX_00FFw					;[01234567] [3]
psraw	mm3, 6							;[01234567] [2]	

psubw	mm4, MMX_10w					;[01234567] [3]
psraw	mm5, 4							;[01234567] [2]

pmullw	mm4, MMX_Ycoeff					;[01234567] [3]
psraw	mm7, 6							;[01234567] [2]

paddsw	mm5, MMX_clip
packuswb mm3, mm3						;[01234567] [2] mm4: R3R2R1R0R3R2R1R0

psubusw	mm5, MMX_clip
packuswb mm7, mm7						;[01234567] [2] mm6: B3B2B1B0B3B2B1B0

pand	mm5, MMX_grnmask				;[012 4567] [2] mm7: <G3><G2><G1><G0>
psrlq	mm7, 2							;[01234567] [2]

punpcklbw mm7, mm3						;[012 4567] [2] mm6: R3B3R2B2R1B1R0B0

movq	mm3, qword ptr [edx+ebp*2]		;[01234567] [4] Y
psrlw	mm7, 1							;[01234567] [2]

pand	mm7, MMX_rbmask					;[01234567] [2] mm6: <RB3><RB2><RB1><RB0>
psrlw	mm3, 8							;[01234567] [4]

por	mm7, mm5							;[01234567] [2] mm7: P7P5P3P1
movq	mm5, mm6						;[01234567] [A]

psubw	mm3, MMX_10w					;[01234567] [4]
punpcklwd mm6, mm7						;[01234567] [A] mm4: P3P2P1P0

pmullw	mm3, MMX_Ycoeff					;[0123456 ] [4]
punpckhwd mm5, mm7						;[0123456 ] [A} mm5: P7P6P5P4

movq	qword ptr [eax+ebp*4], mm6		;[012345  ] [A]
movq	mm6, mm4						;[0123456 ] [3]

movq	qword ptr [eax+ebp*4+8], mm5	;[0123456 ] [A]
paddw	mm6, mm0						;[01234 6 ] [3] mm6: <B3><B2><B1><B0>

movq	mm5, mm4						;[0123456 ] [3]
paddw	mm4, mm1						;[0123456 ] [3] mm4: <R3><R2><R1><R0>

paddw	mm5, mm2						;[0123456 ] [3] mm5: <G3><G2><G1><G0>
psraw	mm4, 6							;[0123456 ] [3]

movq	mm7, mm3						;[01234567] [4]
psraw	mm5, 4							;[01234567] [3]

paddw	mm7, mm0						;[01234567] [4] mm6: <B3><B2><B1><B0>
psraw	mm6, 6							;[01234567] [3]

movq	mm0, mm3						;[01234567] [4]
packuswb mm4, mm4						;[01234567] [3] mm4: R3R2R1R0R3R2R1R0


packuswb mm6, mm6						;[01 34567] [3] mm6: B3B2B1B0B3B2B1B0
paddw	mm3, mm1						;[01234567] [4] mm4: <R3><R2><R1><R0>

psrlq	mm6, 2
paddw	mm0, mm2						;[01 34567] [4] mm5: <G3><G2><G1><G0>

paddsw	mm5, MMX_clip
punpcklbw mm6, mm4						;[01 3 567] [3] mm6: B3B3B2B2B1B1B0B0

psubusw	mm5, MMX_clip
psrlw	mm6, 1							;[01 3 567] [3]

pand	mm6, MMX_rbmask					;[01 3 567] [3] mm6: <B3><B2><B1><B0>
psraw	mm3, 6							;[01 3 567] [4]

pand	mm5, MMX_grnmask				;[01 3 567] [3] mm7: <G3><G2><G1><G0>
psraw	mm0, 4							;[01 3 567] [4]

por	mm6, mm5							;[01 3  67] [3] mm4: P6P4P2P0	
psraw	mm7, 6							;[01 3  67] [4]

paddsw	mm0, MMX_clip
packuswb mm3, mm3						;[01 3  67] [4] mm4: R3R2R1R0R3R2R1R0

psubusw	mm0, MMX_clip
packuswb mm7, mm7						;[01 3  67] mm6: B3B2B1B0B3B2B1B0

pand	mm0, MMX_grnmask				;[01    67] mm7: <G3><G2><G1><G0>
psrlq	mm7, 2

punpcklbw mm7, mm3						;[01    67] mm6: R3B3R2B2R1B1R0B0
movq	mm1, mm6

psrlw	mm7, 1
add	ebp, 4

pand	mm7, MMX_rbmask					;[01    67] mm6: <B3><B2><B1><B0>

por	mm0, mm7							;[01    67] mm0: P7P5P3P1

punpcklwd mm6, mm0						;[01    6 ] mm4: P3P2P1P0

punpckhwd mm1, mm0						;[ 1    6 ] mm5: P7P6P5P4
movq	qword ptr [ebx+ebp*4-10h], mm6

movq	qword ptr [ebx+ebp*4-8], mm1
jnz	col_loop_MMX16

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB16_row_MMX	endp

;--------------------------------------------------------------------------

public _asm_YUVtoRGB32_row_ISSE
_asm_YUVtoRGB32_row_ISSE proc near

arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

push	ebx
push	esi
push	edi
push	ebp
mov	eax, [esp+10h+arg_18]
mov	ebp, eax
mov	ebx, eax
shl	ebx, 3
add	eax, eax
add	[esp+10h+arg_0], ebx
add	[esp+10h+arg_4], ebx
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp

mov	esi, [esp+10h+arg_10]
mov	edi, [esp+10h+arg_14]
mov	ecx, [esp+10h+arg_8]
mov	edx, [esp+10h+arg_C]
mov	eax, [esp+10h+arg_0]
mov	ebx, [esp+10h+arg_4]

col_loop_SSE:
prefetchnta byte ptr [esi+ebp+20h]
prefetchnta byte ptr [edi+ebp+20h]
prefetchnta byte ptr [ecx+ebp*2+20h]
prefetchnta byte ptr [edx+ebp*2+20h]

movd	mm0, dword ptr [esi+ebp]		;U (byte)
pxor	mm7, mm7

movd	mm1, dword ptr [edi+ebp]		;V (byte)
punpcklbw mm0, mm7						;U (word)

psubw	mm0, MMX_80w
punpcklbw mm1, mm7						;V (word)

psubw	mm1, MMX_80w
movq	mm2, mm0

pmullw	mm2, MMX_Ugrncoeff
movq	mm3, mm1

pmullw	mm3, MMX_Vgrncoeff
pmullw	mm0, MMX_Ublucoeff
pmullw	mm1, MMX_Vredcoeff
paddw	mm2, mm3

;mm0: blue
;mm1: red
;mm2: green

movq	mm6, qword ptr [ecx+ebp*2]		;Y
pand	mm6, MMX_00FFw
psubw	mm6, MMX_10w
pmullw	mm6, MMX_Ycoeff
movq	mm4, mm6
paddw	mm6, mm0						;mm6: <B3><B2><B1><B0>
movq	mm5, mm4
paddw	mm4, mm1						;mm4: <R3><R2><R1><R0>
paddw	mm5, mm2						;mm5: <G3><G2><G1><G0>
psraw	mm6, 6
psraw	mm4, 6
packuswb mm6, mm6						;mm6: B3B2B1B0B3B2B1B0
psraw	mm5, 6
packuswb mm4, mm4						;mm4: R3R2R1R0R3R2R1R0
punpcklbw mm6, mm4						;mm6: R3B3R2B2R1B1R0B0
packuswb mm5, mm5						;mm5: G3G2G1G0G3G2G1G0
punpcklbw mm5, mm5						;mm5: G3G3G2G2G1G1G0G0
movq	mm4, mm6
punpcklbw mm6, mm5						;mm6: G1R1G1B2G0R0G0B0
punpckhbw mm4, mm5						;mm4: G3R3G3B3G2R2G2B2

movq	mm7, qword ptr [ecx+ebp*2]		;Y
psrlw	mm7, 8
psubw	mm7, MMX_10w
pmullw	mm7, MMX_Ycoeff
movq	mm3, mm7
paddw	mm7, mm0						;mm7: final blue
movq	mm5, mm3
paddw	mm3, mm1						;mm3: final red
paddw	mm5, mm2						;mm5: final green
psraw	mm7, 6
psraw	mm3, 6
packuswb mm7, mm7						;mm7: B3B2B1B0B3B2B1B0
psraw	mm5, 6
packuswb mm3, mm3						;mm3: R3R2R1R0R3R2R1R0
punpcklbw mm7, mm3						;mm7: R3B3R2B2R1B1R0B0
packuswb mm5, mm5						;mm5: G3G2G1G0G3G2G1G0
punpcklbw mm5, mm5						;mm5: G3G3G2G2G1G1G0G0
movq	mm3, mm7
punpcklbw mm7, mm5						;mm7: G1R1G1B2G0R0G0B0
punpckhbw mm3, mm5						;mm3: G3R3G3B3G2R2G2B2

;mm3	P7:P5
;mm4	P6:P4
;mm6	P2:P0
;mm7	P3:P1

movq	mm5, mm6
punpckldq mm5, mm7						;P1:P0
punpckhdq mm6, mm7						;P3:P2
movq	mm7, mm4
punpckldq mm4, mm3						;P5:P4
punpckhdq mm7, mm3						;P7:P6

movntq	qword ptr [eax+ebp*8], mm5
movntq	qword ptr [eax+ebp*8+8], mm6
movntq	qword ptr [eax+ebp*8+10h], mm4
movntq	qword ptr [eax+ebp*8+18h], mm7

movq	mm6, qword ptr [edx+ebp*2]		;Y
pand	mm6, MMX_00FFw
psubw	mm6, MMX_10w
pmullw	mm6, MMX_Ycoeff
movq	mm4, mm6
paddw	mm6, mm0						;mm6: <B3><B2><B1><B0>
movq	mm5, mm4
paddw	mm4, mm1						;mm4: <R3><R2><R1><R0>
paddw	mm5, mm2						;mm5: <G3><G2><G1><G0>
psraw	mm6, 6
psraw	mm4, 6
packuswb mm6, mm6						;mm6: B3B2B1B0B3B2B1B0
psraw	mm5, 6
packuswb mm4, mm4						;mm4: R3R2R1R0R3R2R1R0
punpcklbw mm6, mm4						;mm6: R3B3R2B2R1B1R0B0
packuswb mm5, mm5						;mm5: G3G2G1G0G3G2G1G0
punpcklbw mm5, mm5						;mm5: G3G3G2G2G1G1G0G0
movq	mm4, mm6
punpcklbw mm6, mm5						;mm6: G1R1G1B2G0R0G0B0
punpckhbw mm4, mm5						;mm4: G3R3G3B3G2R2G2B2

movq	mm7, qword ptr [edx+ebp*2]		;Y
psrlw	mm7, 8
psubw	mm7, MMX_10w
pmullw	mm7, MMX_Ycoeff
movq	mm3, mm7
paddw	mm7, mm0						;mm7: final blue
movq	mm5, mm3
paddw	mm3, mm1						;mm3: final red
paddw	mm5, mm2						;mm5: final green
psraw	mm7, 6
psraw	mm3, 6
packuswb mm7, mm7						;mm7: B3B2B1B0B3B2B1B0
psraw	mm5, 6
packuswb mm3, mm3						;mm3: R3R2R1R0R3R2R1R0
punpcklbw mm7, mm3						;mm7: R3B3R2B2R1B1R0B0
packuswb mm5, mm5						;mm5: G3G2G1G0G3G2G1G0
punpcklbw mm5, mm5						;mm5: G3G3G2G2G1G1G0G0
movq	mm3, mm7
punpcklbw mm7, mm5						;mm7: G1R1G1B2G0R0G0B0
punpckhbw mm3, mm5						;mm3: G3R3G3B3G2R2G2B2

;mm3	P7:P5
;mm4	P6:P4
;mm6	P2:P0
;mm7	P3:P1

movq	mm5, mm6
punpckldq mm5, mm7						;P1:P0
punpckhdq mm6, mm7						;P3:P2
movq	mm7, mm4
punpckldq mm4, mm3						;P5:P4
punpckhdq mm7, mm3						;P7:P6

movntq	qword ptr [ebx+ebp*8], mm5
movntq	qword ptr [ebx+ebp*8+8], mm6

movntq	qword ptr [ebx+ebp*8+10h], mm4
movntq	qword ptr [ebx+ebp*8+18h], mm7

add	ebp, 4

jnz	col_loop_SSE

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB32_row_ISSE endp




public _asm_YUVtoRGB24_row_ISSE
_asm_YUVtoRGB24_row_ISSE proc near

var_24=	qword ptr -24h
var_1C=	qword ptr -1Ch
var_14=	dword ptr -14h
arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

;.FPO (7, 9, 0, 0, 0, 0)
push	ebx
push	esi
push	edi
push	ebp
mov	eax, [esp+10h+arg_18]
mov	ebp, eax
add	eax, eax
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp

mov	esi, [esp+10h+arg_10]
mov	edi, [esp+10h+arg_14]
mov	ecx, [esp+10h+arg_8]
mov	edx, [esp+10h+arg_C]
mov	eax, [esp+10h+arg_0]
mov	ebx, [esp+10h+arg_4]

movd	mm0, esp
sub	esp, 14h
and	esp, 0FFFFFFF8h
movd	[esp+24h+var_14], mm0

col_loop_ISSE24:
prefetchnta byte ptr [esi+ebp+20h]
prefetchnta byte ptr [edi+ebp+20h]
prefetchnta byte ptr [ecx+ebp*2+20h]
prefetchnta byte ptr [edx+ebp*2+20h]

movd	mm0, dword ptr [esi+ebp]			;U (byte)
pxor	mm7, mm7

movd	mm1, dword ptr [edi+ebp]			;V (byte)
punpcklbw mm0, mm7							;U (word)

movd	mm2, dword ptr [ecx+ebp*2]			;Y low
punpcklbw mm1, mm7							;V (word)

movd	mm3, dword ptr [edx+ebp*2]			;Y high
punpcklbw mm2, mm7							;Y1 (word)

psubw	mm2, MMX_10w
punpcklbw mm3, mm7							;Y2 (word)

psubw	mm3, MMX_10w

psubw	mm0, MMX_80w
psubw	mm1, MMX_80w

movq	[esp+24h+var_24], mm0
movq	[esp+24h+var_1C], mm1

;group 1

pmullw	mm2, MMX_Ycoeff						;[lazy]
pmullw	mm3, MMX_Ycoeff						;[lazy]

pshufw	mm6, mm0, 0							;mm6 = U0U0U0U0
pshufw	mm7, mm1, 0							;mm7 = V0V0V0V0

pmullw	mm6, MMX_Ucoeff0
pshufw	mm4, mm2, 40h						;mm4 = Y1Y0Y0Y0 [high]
pmullw	mm7, MMX_Vcoeff0
pshufw	mm5, mm3, 40h						;mm4 = Y1Y0Y0Y0 [low]

paddw	mm4, mm6
paddw	mm5, mm6
paddw	mm4, mm7
paddw	mm5, mm7

psraw	mm4, 6
psraw	mm5, 6

;group 2

pshufw	mm6, [esp+24h+var_24], 50h	;mm6 = U1U1U0U0
pshufw	mm7, [esp+24h+var_1C], 50h	;mm7 = V1V1V0V0

pmullw	mm6, MMX_Ucoeff1
pshufw	mm0, mm2, 0A5h				;mm0 = Y2Y2Y1Y1		[high]
pmullw	mm7, MMX_Vcoeff1
pshufw	mm1, mm3, 0A5h				;mm1 = Y2Y2Y1Y1		[low]

paddw	mm0, mm6
paddw	mm1, mm6
paddw	mm0, mm7
paddw	mm1, mm7

psraw	mm0, 6
psraw	mm1, 6

packuswb mm4, mm0
packuswb mm5, mm1

pshufw	mm6, [esp+24h+var_24], 55h	;mm6 = U1U1U1U1
pshufw	mm7, [esp+24h+var_1C], 55h	;mm7 = V1V1V1V1

movntq	qword ptr [eax], mm4		;[lazy write]
movntq	qword ptr [ebx], mm5		;[lazy write]

pmullw	mm6, MMX_Ucoeff2
pshufw	mm4, mm2, 0FEh				;mm4 = Y3Y3Y3Y2		[high]
pmullw	mm7, MMX_Vcoeff2
pshufw	mm5, mm3, 0FEh				;mm5 = Y3Y3Y3Y2		[low]

paddw	mm4, mm6
paddw	mm5, mm6
paddw	mm4, mm7
paddw	mm5, mm7

psraw	mm4, 6
psraw	mm5, 6

;next 3 groups

movd	mm2, dword ptr [ecx+ebp*2+4];Y low
pxor	mm7, mm7

movd	mm3, dword ptr [edx+ebp*2+4];Y high
punpcklbw mm2, mm7					;U (word)

psubw	mm2, MMX_10w
punpcklbw mm3, mm7					;V (word)

psubw	mm3, MMX_10w

;group 1

pmullw	mm2, MMX_Ycoeff				;[init]
pmullw	mm3, MMX_Ycoeff				;[init]

pshufw	mm6, [esp+24h+var_24], 0AAh	;mm6 = U2U2U2U2
pshufw	mm7, [esp+24h+var_1C], 0AAh	;mm7 = V2V2V2V2

pmullw	mm6, MMX_Ucoeff0
pshufw	mm0, mm2, 40h				;mm0 = Y1Y0Y0Y0 [high]
pmullw	mm7, MMX_Vcoeff0
pshufw	mm1, mm3, 40h				;mm1 = Y1Y0Y0Y0 [low]

paddw	mm0, mm6
paddw	mm1, mm6
paddw	mm0, mm7
paddw	mm1, mm7

psraw	mm0, 6
psraw	mm1, 6

packuswb mm4, mm0
packuswb mm5, mm1

;group 2

pshufw	mm6, [esp+24h+var_24], 0FAh	;mm6 = U3U3U2U2
pshufw	mm7, [esp+24h+var_1C], 0FAh	;mm7 = V3V3V2V2

movntq	qword ptr [eax+8], mm4
movntq	qword ptr [ebx+8], mm5

pmullw	mm6, MMX_Ucoeff1
pshufw	mm4, mm2, 0A5h				;mm4 = Y2Y2Y1Y1		[high]
pmullw	mm7, MMX_Vcoeff1
pshufw	mm5, mm3, 0A5h				;mm5 = Y2Y2Y1Y1		[low]

paddw	mm4, mm6
paddw	mm5, mm6
paddw	mm4, mm7
paddw	mm5, mm7

psraw	mm4, 6
psraw	mm5, 6

;group 3

pshufw	mm0, [esp+24h+var_24], 0FFh	;mm6 = U3U3U3U3
pshufw	mm1, [esp+24h+var_1C], 0FFh	;mm7 = V3V3V3V3

pmullw	mm0, MMX_Ucoeff2
pshufw	mm2, mm2, 0FEh				;mm6 = Y3Y3Y3Y2		[high]
pmullw	mm1, MMX_Vcoeff2
pshufw	mm3, mm3, 0FEh				;mm7 = Y3Y3Y3Y2		[low]

paddw	mm2, mm0
paddw	mm3, mm0
paddw	mm2, mm1
paddw	mm3, mm1

psraw	mm2, 6
psraw	mm3, 6

packuswb mm4, mm2
packuswb mm5, mm3


movntq	qword ptr [eax+10h], mm4
add	eax, 18h
movntq	qword ptr [ebx+10h], mm5
add	ebx, 18h

;done

add	ebp, 4
jnz	col_loop_ISSE24

mov	esp, [esp+24h+var_14]

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB24_row_ISSE endp


public _asm_YUVtoRGB16_row_ISSE
_asm_YUVtoRGB16_row_ISSE proc near

arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

push	ebx
push	esi
push	edi
push	ebp
mov	eax, [esp+10h+arg_18]
mov	ebp, eax
mov	ebx, eax
shl	ebx, 2
add	eax, eax
add	[esp+10h+arg_0], ebx
add	[esp+10h+arg_4], ebx
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp

mov	esi, [esp+10h+arg_10]
mov	edi, [esp+10h+arg_14]
mov	ecx, [esp+10h+arg_8]
mov	edx, [esp+10h+arg_C]
mov	eax, [esp+10h+arg_0]
mov	ebx, [esp+10h+arg_4]

col_loop_ISSE16:
prefetchnta byte ptr [esi+ebp+20h]
prefetchnta byte ptr [edi+ebp+20h]

movd	mm0, dword ptr [esi+ebp]		;[0       ] U (byte)
pxor	mm7, mm7						;[0      7] 

movd	mm1, dword ptr [edi+ebp]		;[01     7] V (byte)
punpcklbw mm0, mm7						;[01     7] U (word)

psubw	mm0, MMX_80w					;[01     7] 
punpcklbw mm1, mm7						;[01     7] V (word)

psubw	mm1, MMX_80w					;[01      ] 
movq	mm2, mm0						;[012     ] 

pmullw	mm2, MMX_Ugrncoeff				;[012     ] 
movq	mm3, mm1						;[0123    ] 

;mm0: blue
;mm1: red
;mm2: green

prefetchnta byte ptr [ecx+ebp*2+20h]
prefetchnta byte ptr [edx+ebp*2+20h]

movq	mm6, qword ptr [ecx+ebp*2]		;[0123  6 ] [1] Y
;<-->

pmullw	mm3, MMX_Vgrncoeff				;[0123    ] 
movq	mm7, mm6						;[012   67] [2] Y

pmullw	mm0, MMX_Ublucoeff				;[0123    ] 
psrlw	mm7, 8							;[012   67] [2]

pmullw	mm1, MMX_Vredcoeff				;[0123    ] 
;<-->

pand	mm6, MMX_00FFw					;[012   67] [1]
paddw	mm2, mm3						;[012   6 ] [C]

psubw	mm6, MMX_10w					;[012   67] [1]

pmullw	mm6, MMX_Ycoeff					;[012   67] [1]

psubw	mm7, MMX_10w					;[012   67] [2]
movq	mm4, mm6						;[012 4 67] [1]

pmullw	mm7, MMX_Ycoeff					;[012   67] [2]
movq	mm5, mm6						;[012 4567] [1]

paddw	mm6, mm0						;[012 4 67] [1] mm6: <B3><B2><B1><B0>
paddw	mm4, mm1						;[012 4567] [1] mm4: <R3><R2><R1><R0>

paddw	mm5, mm2						;[012 4567] [1] mm5: <G3><G2><G1><G0>
psraw	mm4, 6							;[012 4567] [1]

movq	mm3, mm7						;[01234567] [2]
psraw	mm5, 4							;[01234567] [1]

paddw	mm7, mm0						;[01234567] [2] mm6: <B3><B2><B1><B0>
psraw	mm6, 6							;[01234567] [1]

paddsw	mm5, MMX_clip
packuswb mm6, mm6						;[01234567] [1] mm6: B3B2B1B0B3B2B1B0

psubusw	mm5, MMX_clip
packuswb mm4, mm4						;[01234567] [1] mm4: R3R2R1R0R3R2R1R0

pand	mm5, MMX_grnmask				;[01234567] [1] mm7: <G3><G2><G1><G0>
psrlq	mm6, 2							;[01234567] [1]

punpcklbw mm6, mm4						;[0123 567] [1] mm4: R3B3R2B2R1B1R0B0

movq	mm4, qword ptr [edx+ebp*2]		;[01234567] [3] Y
psrlw	mm6, 1							;[01234567] [1]

pand	mm6, MMX_rbmask					;[01234567] [1] mm6: <RB3><RB2><RB1><RB0>

por	mm6, mm5							;[01234 67] [1] mm6: P6P4P2P0
movq	mm5, mm3						;[01234567] [2]

paddw	mm3, mm1						;[01234567] [2] mm4: <R3><R2><R1><R0>
paddw	mm5, mm2						;[01234567] [2] mm5: <G3><G2><G1><G0>

pand	mm4, MMX_00FFw					;[01234567] [3]
psraw	mm3, 6							;[01234567] [2]	

psubw	mm4, MMX_10w					;[01234567] [3]
psraw	mm5, 4							;[01234567] [2]

pmullw	mm4, MMX_Ycoeff					;[01234567] [3]
psraw	mm7, 6							;[01234567] [2]

paddsw	mm5, MMX_clip
packuswb mm3, mm3						;[01234567] [2] mm4: R3R2R1R0R3R2R1R0

psubusw	mm5, MMX_clip
packuswb mm7, mm7						;[01234567] [2] mm6: B3B2B1B0B3B2B1B0

pand	mm5, MMX_grnmask				;[012 4567] [2] mm7: <G3><G2><G1><G0>
psrlq	mm7, 2							;[01234567] [2]

punpcklbw mm7, mm3						;[012 4567] [2] mm6: R3B3R2B2R1B1R0B0

movq	mm3, qword ptr [edx+ebp*2]		;[01234567] [4] Y
psrlw	mm7, 1							;[01234567] [2]

pand	mm7, MMX_rbmask					;[01234567] [2] mm6: <RB3><RB2><RB1><RB0>
psrlw	mm3, 8							;[01234567] [4]

por	mm7, mm5							;[01234567] [2] mm7: P7P5P3P1
movq	mm5, mm6						;[01234567] [A]

psubw	mm3, MMX_10w					;[01234567] [4]
punpcklwd mm6, mm7						;[01234567] [A] mm4: P3P2P1P0

pmullw	mm3, MMX_Ycoeff					;[0123456 ] [4]
punpckhwd mm5, mm7						;[0123456 ] [A} mm5: P7P6P5P4

movntq	qword ptr [eax+ebp*4], mm6		;[012345  ] [A]
movq	mm6, mm4						;[0123456 ] [3]

movntq	qword ptr [eax+ebp*4+8], mm5	;[0123456 ] [A]
paddw	mm6, mm0						;[01234 6 ] [3] mm6: <B3><B2><B1><B0>

movq	mm5, mm4						;[0123456 ] [3]
paddw	mm4, mm1						;[0123456 ] [3] mm4: <R3><R2><R1><R0>

paddw	mm5, mm2						;[0123456 ] [3] mm5: <G3><G2><G1><G0>
psraw	mm4, 6							;[0123456 ] [3]

movq	mm7, mm3						;[01234567] [4]
psraw	mm5, 4							;[01234567] [3]

paddw	mm7, mm0						;[01234567] [4] mm6: <B3><B2><B1><B0>
psraw	mm6, 6							;[01234567] [3]

movq	mm0, mm3						;[01234567] [4]
packuswb mm4, mm4						;[01234567] [3] mm4: R3R2R1R0R3R2R1R0


packuswb mm6, mm6						;[01 34567] [3] mm6: B3B2B1B0B3B2B1B0
paddw	mm3, mm1						;[01234567] [4] mm4: <R3><R2><R1><R0>

psrlq	mm6, 2
paddw	mm0, mm2						;[01 34567] [4] mm5: <G3><G2><G1><G0>

paddsw	mm5, MMX_clip
punpcklbw mm6, mm4						;[01 3 567] [3] mm6: B3B3B2B2B1B1B0B0

psubusw	mm5, MMX_clip
psrlw	mm6, 1							;[01 3 567] [3]

pand	mm6, MMX_rbmask					;[01 3 567] [3] mm6: <B3><B2><B1><B0>
psraw	mm3, 6							;[01 3 567] [4]

pand	mm5, MMX_grnmask				;[01 3 567] [3] mm7: <G3><G2><G1><G0>
psraw	mm0, 4							;[01 3 567] [4]

por	mm6, mm5							;[01 3  67] [3] mm4: P6P4P2P0	
psraw	mm7, 6							;[01 3  67] [4]

paddsw	mm0, MMX_clip
packuswb mm3, mm3						;[01 3  67] [4] mm4: R3R2R1R0R3R2R1R0

psubusw	mm0, MMX_clip
packuswb mm7, mm7						;[01 3  67] mm6: B3B2B1B0B3B2B1B0

pand	mm0, MMX_grnmask				;[01    67] mm7: <G3><G2><G1><G0>
psrlq	mm7, 2

punpcklbw mm7, mm3						;[01    67] mm6: R3B3R2B2R1B1R0B0
movq	mm1, mm6

psrlw	mm7, 1
add	ebp, 4

pand	mm7, MMX_rbmask					;[01    67] mm6: <B3><B2><B1><B0>

por	mm0, mm7							;[01    67] mm0: P7P5P3P1

punpcklwd mm6, mm0						;[01    6 ] mm4: P3P2P1P0

punpckhwd mm1, mm0						;[ 1    6 ] mm5: P7P6P5P4
movntq	qword ptr [ebx+ebp*4-10h], mm6

movntq	qword ptr [ebx+ebp*4-8], mm1
jnz	col_loop_ISSE16

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB16_row_ISSE endp


;==========================================================================
;
;	SSE2 (Pentium 4) implementation
;
;==========================================================================


public _asm_YUVtoRGB32_row_SSE2
_asm_YUVtoRGB32_row_SSE2 proc near

arg_0= dword ptr  4
arg_4= dword ptr  8
arg_8= dword ptr  0Ch
arg_C= dword ptr  10h
arg_10=	dword ptr  14h
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch

push	ebx
push	esi
push	edi
push	ebp

mov	eax, [esp+10h+arg_18]
mov	ebp, eax
mov	ebx, eax
shl	ebx, 3
add	eax, eax
add	[esp+10h+arg_0], ebx
add	[esp+10h+arg_4], ebx
add	[esp+10h+arg_8], eax
add	[esp+10h+arg_C], eax
add	[esp+10h+arg_10], ebp
add	[esp+10h+arg_14], ebp
neg	ebp

mov	esi, [esp+10h+arg_10]
mov	edi, [esp+10h+arg_14]
mov	ecx, [esp+10h+arg_8]
mov	edx, [esp+10h+arg_C]
mov	eax, [esp+10h+arg_0]
mov	ebx, [esp+10h+arg_4]

col_loop_SSE2:
prefetchnta byte ptr [esi+ebp+20h]
prefetchnta byte ptr [edi+ebp+20h]
prefetchnta byte ptr [ecx+ebp*2+20h]
prefetchnta byte ptr [edx+ebp*2+20h]

movq	xmm0, qword ptr	[esi+ebp]			;xmm0 = U7|U6|U5|U4|U3|U2|U1|U0
pxor	xmm7, xmm7

movq	xmm1, qword ptr	[edi+ebp]			;xmm1 = V7|V6|V5|V4|V3|V2|V1|V0

punpcklbw xmm0,	xmm7
punpcklbw xmm1,	xmm7

psubw	xmm0, xmmword ptr [SSE2_80w]		;xmm0 = U3|U2|U1|U0
psubw	xmm1, xmmword ptr [SSE2_80w]		;xmm1 = V3|V2|V1|V0

movdqa	xmm2, xmm0
pmullw	xmm0, xmmword ptr [SSE2_Ugrncoeff]
pmullw	xmm2, xmmword ptr [SSE2_Ublucoeff]

movdqa	xmm3, xmm1
pmullw	xmm1, xmmword ptr [SSE2_Vredcoeff]
pmullw	xmm3, xmmword ptr [SSE2_Vgrncoeff]

paddw	xmm0, xmm1							;xmm0 = cG7|cG6|cG5|cG4|cG3|cG2|cG1|cG0

movdqu	xmm3, xmmword ptr [ecx+ebp*2]		;xmm4 = YF|YE|YD|YC|YB|YA|Y9|Y8|Y7|Y6|Y5|Y4|Y3|Y2|Y1|Y0
movq	xmm4, xmm4							;xmm5 = YF|YE|YD|YC|YB|YA|Y9|Y8|Y7|Y6|Y5|Y4|Y3|Y2|Y1|Y0
pand	xmm3, xmmword ptr [SSE2_Ylow]		;xmm4 = YE|YC|YA|Y8|Y6|Y4|Y2|Y0
psrlw	xmm4, 8								;xmm5 = YF|YD|YB|Y9|Y7|Y5|Y3|Y1

psubw	xmm3, xmmword ptr [SSE2_Ybias]
pmullw	xmm3, xmmword ptr [SSE2_Ycoeff]
psubw	xmm4, xmmword ptr [SSE2_Ybias]
pmullw	xmm4, xmmword ptr [SSE2_Ycoeff]

;register layout at this point:
;xmm0:	chroma green
;xmm1:	chroma red
;xmm2:	chroma blue
;xmm3:	Y low
;xmm4:	Y high

movdqa	xmm5, xmm4
movdqa	xmm6, xmm4
paddw	xmm4, xmm0
paddw	xmm5, xmm1
paddw	xmm6, xmm2
paddw	xmm0, xmm3
paddw	xmm1, xmm3
paddw	xmm2, xmm3

psraw	xmm0, 6
psraw	xmm1, 6
psraw	xmm2, 6
psraw	xmm4, 6
psraw	xmm5, 6
psraw	xmm6, 6

packuswb xmm0, xmm0
packuswb xmm1, xmm1
packuswb xmm2, xmm2
packuswb xmm4, xmm4
packuswb xmm5, xmm5
packuswb xmm6, xmm6

punpcklbw xmm0,	xmm0						;xmm3 = GE|GE|GC|GC|GA|GA|G8|G8|G6|G6|G4|G4|G2|G2|G0|G0
punpcklbw xmm4,	xmm4						;xmm4 = GF|GF|GD|GD|GB|GB|G9|G9|G7|G7|G5|G5|G3|G3|G1|G1
punpcklbw xmm2,	xmm1						;xmm2 = RE|BE|RC|BC|RA|BA|R8|B8|R6|B6|R4|B4|R2|B2|R0|B0
punpcklbw xmm6,	xmm5						;xmm6 = RF|BF|RD|BD|RB|BB|R9|B9|R7|B7|R5|B5|R3|B3|B1|B1

movdqa	xmm1, xmm2
movdqa	xmm5, xmm6

punpcklbw xmm1,	xmm0						;xmm1 = p6|p4|p2|p0
punpckhbw xmm2,	xmm0						;xmm2 = pE|pC|pA|p8
punpcklbw xmm5,	xmm4						;xmm5 = p7|p5|p3|p1
punpckhbw xmm6,	xmm4						;xmm6 = pF|pD|pB|p9

movdqa	xmm0, xmm1
punpckldq xmm0,	xmm5						;xmm0 = p3|p2|p1|p0
punpckhdq xmm1,	xmm5						;xmm1 = p7|p6|p5|p4
movdqa	xmm3, xmm2
punpckldq xmm2,	xmm6						;xmm2 = pB|pA|p9|p8
punpckhdq xmm3,	xmm6						;xmm3 = pF|pE|pD|pC

movdqu	xmmword	ptr [ebx+ebp*8], xmm0
movdqu	xmmword	ptr [ebx+ebp*8+8], xmm1

movdqu	xmmword	ptr [ebx+ebp*8+10h], xmm2
movdqu	xmmword	ptr [ebx+ebp*8+18h], xmm3

add	ebp, 4

jnz	col_loop_SSE2

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB32_row_SSE2 endp


public _asm_YUVtoRGB24_SSE2
_asm_YUVtoRGB24_SSE2 proc near

var_18=	dword ptr -18h
var_14=	dword ptr -14h
var_10=	dword ptr -10h
var_C= dword ptr -0Ch
var_8= dword ptr -8
arg_0= dword ptr  4
arg_4= xmmword ptr  8
arg_14=	dword ptr  18h
arg_18=	dword ptr  1Ch
arg_1C=	dword ptr  20h
arg_64=	xmmword	ptr  68h
arg_74=	xmmword	ptr  78h
arg_84=	xmmword	ptr  88h
arg_94=	xmmword	ptr  98h
arg_A4=	xmmword	ptr  0A8h
arg_B4=	xmmword	ptr  0B8h
arg_C4=	xmmword	ptr  0C8h
arg_D4=	xmmword	ptr  0D8h

push	ebx
push	esi
push	edi
push	ebp

mov	eax, [esp+10h+arg_18]
mov	ebp, eax
add	eax, eax
mov	esi, dword ptr [esp+10h+arg_4+0Ch]
mov	edi, [esp+10h+arg_14]
add	esi, ebp
add	edi, ebp
mov	ecx, dword ptr [esp+10h+arg_4+4]
mov	edx, dword ptr [esp+10h+arg_4+8]
add	ecx, eax
add	edx, eax
mov	eax, [esp+10h+arg_0]
mov	ebx, dword ptr [esp+10h+arg_4]
neg	ebp

;store esp in the SEH chain and set esp=constant_struct
push	0
push	fs:0 ;large dword ptr fs:0
mov	fs:0, esp ;large fs:0, esp
mov	esp, [esp+18h+arg_1C]

;---- we have no stack at this point!

mov	[esp+18h+var_C], ebp

row_loop_SSE2_24:
mov	ebp, [esp+18h+var_C]

col_loop_SSE2_24:
prefetchnta byte ptr [esi+ebp+80h]
prefetchnta byte ptr [edi+ebp+80h]
prefetchnta byte ptr [ecx+ebp*2+80h]
prefetchnta byte ptr [edx+ebp*2+80h]

;U1|U1|U0|U0|U0|U0|U0|U0
;U2|U2|U2|U2|U1|U1|U1|U1
;U3|U3|U3|U3|U3|U3|U2|U2

movd	xmm0, dword ptr	[esi+ebp]		;xmm0 = U3|U2|U1|U0
pxor	xmm7, xmm7
punpcklbw xmm0,	xmm7					;xmm0 = U3|U2|U1|U0
psubw	xmm0, [esp+18h+arg_4]
punpcklwd xmm0,	xmm0					;xmm0 = U3|U3|U2|U2|U1|U1|U0|U0
pshufd	xmm2, xmm0, 0FEh				;xmm2 = U3|U3|U3|U3|U3|U3|U2|U2
pshufd	xmm1, xmm0, 0A5h				;xmm1 = U2|U2|U2|U2|U1|U1|U1|U1
pshufd	xmm0, xmm0, 40h					;xmm0 = U1|U1|U0|U0|U0|U0|U0|U0

pmullw	xmm0, [esp+18h+arg_84]
pmullw	xmm1, [esp+18h+arg_94]
pmullw	xmm2, [esp+18h+arg_A4]

movd	xmm3, dword ptr	[edi+ebp]		;xmm3 = V3|V2|V1|V0
punpcklbw xmm3,	xmm7					;xmm3 = V3|V2|V1|V0
psubw	xmm3, [esp+18h+arg_4]
punpcklwd xmm3,	xmm3
pshufd	xmm5, xmm3, 0FEh				;xmm5 = V7|V6|V7|V6|V7|V6|V5|V4
pshufd	xmm4, xmm3, 0A5h				;xmm4 = V5|V4|V5|V4|V3|V2|V3|V2
pshufd	xmm3, xmm3, 40h					;xmm3 = V3|V2|V1|V0|V1|V0|V1|V0

pmullw	xmm3, [esp+18h+arg_B4]
pmullw	xmm4, [esp+18h+arg_C4]
pmullw	xmm5, [esp+18h+arg_D4]

paddw	xmm0, xmm3
paddw	xmm1, xmm4
paddw	xmm2, xmm5

movq	xmm3, qword ptr	[ecx+ebp*2]		;xmm3 = Y7 | Y6 | Y5 | Y4 | Y3 | Y2 | Y1 | Y0
punpcklbw xmm3,	xmm7
psubw	xmm3, [esp+18h+arg_64]
pmullw	xmm3, [esp+18h+arg_74]
pshufd	xmm5, xmm3, 0FEh				;xmm5 = Y7|Y6|Y7|Y6|Y7|Y6|Y5|Y4
pshufd	xmm4, xmm3, 0A5h				;xmm4 = Y5|Y4|Y5|Y4|Y3|Y2|Y3|Y2
pshufd	xmm3, xmm3, 40h					;xmm3 = Y3|Y2|Y1|Y0|Y1|Y0|Y1|Y0
pshufhw	xmm5, xmm5, 0FEh				;xmm5 = Y7|Y7|Y7|Y6|Y7|Y6|Y5|Y4
pshuflw	xmm5, xmm5, 0A5h				;xmm5 = Y7|Y7|Y7|Y6|Y6|Y6|Y5|Y5
pshufhw	xmm4, xmm4, 40h					;xmm4 = Y5|Y4|Y4|Y4|Y3|Y2|Y3|Y2
pshuflw	xmm4, xmm4, 0FEh				;xmm4 = Y5|Y4|Y4|Y4|Y3|Y3|Y3|Y2
pshufhw	xmm3, xmm3, 0A5h				;xmm3 = Y2|Y2|Y1|Y1|Y1|Y0|Y1|Y0
pshuflw	xmm3, xmm3, 40h					;xmm3 = Y2|Y2|Y1|Y1|Y1|Y0|Y0|Y0

paddw	xmm3, xmm0
paddw	xmm4, xmm1
paddw	xmm5, xmm2

psraw	xmm3, 6
psraw	xmm4, 6
psraw	xmm5, 6

packuswb xmm3, xmm3
packuswb xmm4, xmm4
packuswb xmm5, xmm5

movdq2q	mm0, xmm3
movdq2q	mm1, xmm4
movdq2q	mm2, xmm5

movq	xmm3, qword ptr	[edx+ebp*2]		;xmm3 = Y7 | Y6 | Y5 | Y4 | Y3 | Y2 | Y1 | Y0
punpcklbw xmm3,	xmm7
psubw	xmm3, [esp+18h+arg_64]
pmullw	xmm3, [esp+18h+arg_74]
pshufd	xmm5, xmm3, 0FEh				;xmm5 = Y7|Y6|Y7|Y6|Y7|Y6|Y5|Y4
pshufd	xmm4, xmm3, 0A5h				;xmm4 = Y5|Y4|Y5|Y4|Y3|Y2|Y3|Y2
pshufd	xmm3, xmm3, 40h					;xmm3 = Y3|Y2|Y1|Y0|Y1|Y0|Y1|Y0
pshufhw	xmm5, xmm5, 0FEh				;xmm5 = Y7|Y7|Y7|Y6|Y7|Y6|Y5|Y4
pshuflw	xmm5, xmm5, 0A5h				;xmm5 = Y7|Y7|Y7|Y6|Y6|Y6|Y5|Y5
pshufhw	xmm4, xmm4, 40h					;xmm4 = Y5|Y4|Y4|Y4|Y3|Y2|Y3|Y2
pshuflw	xmm4, xmm4, 0FEh				;xmm4 = Y5|Y4|Y4|Y4|Y3|Y3|Y3|Y2
pshufhw	xmm3, xmm3, 0A5h				;xmm3 = Y2|Y2|Y1|Y1|Y1|Y0|Y1|Y0
pshuflw	xmm3, xmm3, 40h					;xmm3 = Y2|Y2|Y1|Y1|Y1|Y0|Y0|Y0

paddw	xmm3, xmm0
paddw	xmm4, xmm1
paddw	xmm5, xmm2

psraw	xmm3, 6
psraw	xmm4, 6
psraw	xmm5, 6

packuswb xmm3, xmm3
packuswb xmm4, xmm4
packuswb xmm5, xmm5

movdq2q	mm3, xmm3
movdq2q	mm4, xmm4
movdq2q	mm5, xmm5

movntq	qword ptr [eax], mm0
movntq	qword ptr [eax+8], mm1
movntq	qword ptr [eax+10h], mm2
movntq	qword ptr [ebx], mm3
movntq	qword ptr [ebx+8], mm4
movntq	qword ptr [ebx+10h], mm5
add	eax, 18h
add	ebx, 18h

;done

add	ebp, 4
jnz	col_loop_SSE2_24

mov	ebp, [esp+18h+var_18]
add	eax, ebp
add	ebx, ebp
mov	ebp, [esp+18h+var_14]
add	ecx, ebp
add	edx, ebp
mov	ebp, [esp+18h+var_10]
add	esi, ebp
add	edi, ebp

dec	[esp+18h+var_8]
jnz	row_loop_SSE2_24

;restore esp from SEH chain
mov	esp, fs:0	;large fs:0
pop	fs:0 ; large dword ptr	fs:0
pop	eax

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_asm_YUVtoRGB24_SSE2 endp


_asm_YUVtoRGB16_row_SSE2:
push	ebx
push	esi
push	edi
push	ebp

mov	eax, [esp+2Ch]
mov	ebp, eax
mov	ebx, eax
shl	ebx, 2
add	eax, eax
add	[esp+14h], ebx
add	[esp+18h], ebx
add	[esp+1Ch], eax
add	[esp+20h], eax
add	[esp+24h], ebp
add	[esp+28h], ebp
neg	ebp

mov	esi, [esp+24h]
mov	edi, [esp+28h]
mov	ecx, [esp+1Ch]
mov	edx, [esp+20h]
mov	eax, [esp+14h]
mov	ebx, [esp+18h]

col_loop_SSE2_16:
prefetchnta byte ptr [esi+ebp+20h]
prefetchnta byte ptr [edi+ebp+20h]

movd	mm0, dword ptr [esi+ebp]		;[0       ] U (byte)
pxor	mm7, mm7						;[0      7] 

movd	mm1, dword ptr [edi+ebp]		;[01     7] V (byte)
punpcklbw mm0, mm7						;[01     7] U (word)

psubw	mm0, MMX_80w					;[01     7] 
punpcklbw mm1, mm7						;[01     7] V (word)

psubw	mm1, MMX_80w					;[01      ] 
movq	mm2, mm0						;[012     ] 

pmullw	mm2, MMX_Ugrncoeff				;[012     ] 
movq	mm3, mm1						;[0123    ]

;mm0: blue
;mm1: red
;mm2: green

prefetchnta byte ptr [ecx+ebp*2+20h]
prefetchnta byte ptr [edx+ebp*2+20h]

movq	mm6, qword ptr [ecx+ebp*2]		;[0123  6 ] [1] Y
;<-->

pmullw	mm3, MMX_Vgrncoeff				;[0123    ] 
movq	mm7, mm6						;[012   67] [2] Y

pmullw	mm0, MMX_Ublucoeff				;[0123    ] 
psrlw	mm7, 8							;[012   67] [2]

pmullw	mm1, MMX_Vredcoeff				;[0123    ] 
;<-->

pand	mm6, MMX_00FFw					;[012   67] [1]
paddw	mm2, mm3						;[012   6 ] [C]

psubw	mm6, MMX_10w					;[012   67] [1]

pmullw	mm6, MMX_Ycoeff					;[012   67] [1]

psubw	mm7, MMX_10w					;[012   67] [2]
movq	mm4, mm6						;[012 4 67] [1]

pmullw	mm7, MMX_Ycoeff					;[012   67] [2]
movq	mm5, mm6						;[012 4567] [1]

paddw	mm6, mm0						;[012 4 67] [1] mm6: <B3><B2><B1><B0>
paddw	mm4, mm1						;[012 4567] [1] mm4: <R3><R2><R1><R0>

paddw	mm5, mm2						;[012 4567] [1] mm5: <G3><G2><G1><G0>
psraw	mm4, 6							;[012 4567] [1]

movq	mm3, mm7						;[01234567] [2]
psraw	mm5, 4							;[01234567] [1]

paddw	mm7, mm0						;[01234567] [2] mm6: <B3><B2><B1><B0>
psraw	mm6, 6							;[01234567] [1]

paddsw	mm5, MMX_clip
packuswb mm6, mm6						;[01234567] [1] mm6: B3B2B1B0B3B2B1B0

psubusw	mm5, MMX_clip
packuswb mm4, mm4						;[01234567] [1] mm4: R3R2R1R0R3R2R1R0

pand	mm5, MMX_grnmask				;[01234567] [1] mm7: <G3><G2><G1><G0>
psrlq	mm6, 2							;[01234567] [1]

punpcklbw mm6, mm4						;[0123 567] [1] mm4: R3B3R2B2R1B1R0B0

movq	mm4, qword ptr [edx+ebp*2]		;[01234567] [3] Y
psrlw	mm6, 1							;[01234567] [1]

pand	mm6, MMX_rbmask					;[01234567] [1] mm6: <RB3><RB2><RB1><RB0>

por	mm6, mm5							;[01234 67] [1] mm6: P6P4P2P0
movq	mm5, mm3						;[01234567] [2]

paddw	mm3, mm1						;[01234567] [2] mm4: <R3><R2><R1><R0>
paddw	mm5, mm2						;[01234567] [2] mm5: <G3><G2><G1><G0>

pand	mm4, MMX_00FFw					;[01234567] [3]
psraw	mm3, 6							;[01234567] [2]	

psubw	mm4, MMX_10w					;[01234567] [3]
psraw	mm5, 4							;[01234567] [2]

pmullw	mm4, MMX_Ycoeff					;[01234567] [3]
psraw	mm7, 6							;[01234567] [2]

paddsw	mm5, MMX_clip
packuswb mm3, mm3						;[01234567] [2] mm4: R3R2R1R0R3R2R1R0

psubusw	mm5, MMX_clip
packuswb mm7, mm7						;[01234567] [2] mm6: B3B2B1B0B3B2B1B0

pand	mm5, MMX_grnmask				;[012 4567] [2] mm7: <G3><G2><G1><G0>
psrlq	mm7, 2							;[01234567] [2]

punpcklbw mm7, mm3						;[012 4567] [2] mm6: R3B3R2B2R1B1R0B0

movq	mm3, qword ptr [edx+ebp*2]		;[01234567] [4] Y
psrlw	mm7, 1							;[01234567] [2]

pand	mm7, MMX_rbmask					;[01234567] [2] mm6: <RB3><RB2><RB1><RB0>
psrlw	mm3, 8							;[01234567] [4]

por	mm7, mm5							;[01234567] [2] mm7: P7P5P3P1
movq	mm5, mm6						;[01234567] [A]

psubw	mm3, MMX_10w					;[01234567] [4]
punpcklwd mm6, mm7						;[01234567] [A] mm4: P3P2P1P0

pmullw	mm3, MMX_Ycoeff					;[0123456 ] [4]
punpckhwd mm5, mm7						;[0123456 ] [A} mm5: P7P6P5P4

movntq	qword ptr [eax+ebp*4], mm6		;[012345  ] [A]
movq	mm6, mm4						;[0123456 ] [3]

movntq	qword ptr [eax+ebp*4+8], mm5	;[0123456 ] [A]
paddw	mm6, mm0						;[01234 6 ] [3] mm6: <B3><B2><B1><B0>

movq	mm5, mm4						;[0123456 ] [3]
paddw	mm4, mm1						;[0123456 ] [3] mm4: <R3><R2><R1><R0>

paddw	mm5, mm2						;[0123456 ] [3] mm5: <G3><G2><G1><G0>
psraw	mm4, 6							;[0123456 ] [3]

movq	mm7, mm3						;[01234567] [4]
psraw	mm5, 4							;[01234567] [3]

paddw	mm7, mm0						;[01234567] [4] mm6: <B3><B2><B1><B0>
psraw	mm6, 6							;[01234567] [3]

movq	mm0, mm3						;[01234567] [4]
packuswb mm4, mm4						;[01234567] [3] mm4: R3R2R1R0R3R2R1R0


packuswb mm6, mm6						;[01 34567] [3] mm6: B3B2B1B0B3B2B1B0
paddw	mm3, mm1						;[01234567] [4] mm4: <R3><R2><R1><R0>

psrlq	mm6, 2
paddw	mm0, mm2						;[01 34567] [4] mm5: <G3><G2><G1><G0>

paddsw	mm5, MMX_clip
punpcklbw mm6, mm4						;[01 3 567] [3] mm6: B3B3B2B2B1B1B0B0

psubusw	mm5, MMX_clip
psrlw	mm6, 1							;[01 3 567] [3]

pand	mm6, MMX_rbmask					;[01 3 567] [3] mm6: <B3><B2><B1><B0>
psraw	mm3, 6							;[01 3 567] [4]

pand	mm5, MMX_grnmask				;[01 3 567] [3] mm7: <G3><G2><G1><G0>
psraw	mm0, 4							;[01 3 567] [4]

por	mm6, mm5							;[01 3  67] [3] mm4: P6P4P2P0	
psraw	mm7, 6							;[01 3  67] [4]

paddsw	mm0, MMX_clip
packuswb mm3, mm3						;[01 3  67] [4] mm4: R3R2R1R0R3R2R1R0

psubusw	mm0, MMX_clip
packuswb mm7, mm7						;[01 3  67] mm6: B3B2B1B0B3B2B1B0

pand	mm0, MMX_grnmask				;[01    67] mm7: <G3><G2><G1><G0>
psrlq	mm7, 2

punpcklbw mm7, mm3						;[01    67] mm6: R3B3R2B2R1B1R0B0
movq	mm1, mm6

psrlw	mm7, 1
add	ebp, 4

pand	mm7, MMX_rbmask					;[01    67] mm6: <B3><B2><B1><B0>

por	mm0, mm7							;[01    67] mm0: P7P5P3P1

punpcklwd mm6, mm0						;[01    6 ] mm4: P3P2P1P0

punpckhwd mm1, mm0						;[ 1    6 ] mm5: P7P6P5P4
movntq	qword ptr [ebx+ebp*4-10h], mm6

movntq	qword ptr [ebx+ebp*4-8], mm1
jnz	col_loop_SSE2_16

pop	ebp
pop	edi
pop	esi
pop	ebx
retn
_text ends

end
