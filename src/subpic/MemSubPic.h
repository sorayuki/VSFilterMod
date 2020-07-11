/*
 *	Copyright (C) 2003-2006 Gabest
 *	http://www.gabest.org
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GNU Make; see the file COPYING.  If not, write to
 *  the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 *  http://www.gnu.org/copyleft/gpl.html
 *
 */

#pragma once

#include "ISubPic.h"

enum {MSP_RGB32, MSP_RGB24, MSP_RGB16, MSP_RGB15, MSP_YUY2, MSP_YV12, MSP_IYUV, MSP_AYUV, MSP_RGBA};
enum YCbCrMatrix
{
    YCbCrMatrix_BT601,
    YCbCrMatrix_BT709,
    YCbCrMatrix_BT2020,
    YCbCrMatrix_AUTO
};
enum YCbCrRange
{
    YCbCrRange_PC,
    YCbCrRange_TV,
    YCbCrRange_AUTO
};
// CMemSubPic

class CMemSubPic : public ISubPicImpl
{
#pragma warning(disable: 4799)
    SubPicDesc m_spd;
    int    m_eYCbCrMatrix;
    int     m_eYCbCrRange;

protected:
    STDMETHODIMP_(void*) GetObject(); // returns SubPicDesc*

public:
    CMemSubPic(SubPicDesc& spd, int inYCbCrMatrix, int inYCbCrRange);
    virtual ~CMemSubPic();

    // ISubPic
    STDMETHODIMP GetDesc(SubPicDesc& spd);
    STDMETHODIMP CopyTo(ISubPic* pSubPic);
    STDMETHODIMP ClearDirtyRect(DWORD color);
    STDMETHODIMP Lock(SubPicDesc& spd);
    STDMETHODIMP Unlock(RECT* pDirtyRect);
    STDMETHODIMP AlphaBlt(RECT* pSrc, RECT* pDst, SubPicDesc* pTarget);
};

// CMemSubPicAllocator

class CMemSubPicAllocator : public ISubPicAllocatorImpl
{
    int m_type;
    CSize m_maxsize;
    int    m_eYCbCrMatrix;
    int     m_eYCbCrRange;

    bool Alloc(bool fStatic, ISubPic** ppSubPic);

public:
    CMemSubPicAllocator(int type, SIZE maxsize, int inYCbCrMatrix=YCbCrMatrix_BT601, int inYCbCrRange=YCbCrRange_TV);
};

