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

#include <string>
#include <utility>
#include "stdafx.h"
#include <afxdlgs.h>
#include <atlpath.h>
#include <atlconv.h>
#include "resource.h"
#include "..\subtitles\VobSubFile.h"
#include "..\subtitles\RTS.h"
#include "..\subtitles\SSF.h"
#include "..\SubPic\MemSubPic.h"
#include "vfr.h"

#include <memory>

//
// Generic interface
//

namespace Plugin
{

class CFilter : public CAMThread, public CCritSec
{
private:
    CString m_fn;

protected:
    float m_fps;
    CCritSec m_csSubLock;
    CComPtr<ISubPicQueue> m_pSubPicQueue;
    CComPtr<ISubPicProvider> m_pSubPicProvider;
    DWORD_PTR m_SubPicProviderId;

public:
    CFilter() : m_fps(-1), m_SubPicProviderId(0)
    {
        CAMThread::Create();
    }
    virtual ~CFilter()
    {
        CAMThread::CallWorker(0);
    }

    CString GetFileName()
    {
        CAutoLock cAutoLock(this);
        return m_fn;
    }
    void SetFileName(CString fn)
    {
        CAutoLock cAutoLock(this);
        m_fn = fn;
    }

    bool Render(SubPicDesc& dst, REFERENCE_TIME rt, float fps)
    {
        if(!m_pSubPicProvider)
            return(false);

        CSize size(dst.w, dst.h);

        if(!m_pSubPicQueue)
        {
            CComPtr<ISubPicAllocator> pAllocator = new CMemSubPicAllocator(dst.type, size);

            HRESULT hr;
            if(!(m_pSubPicQueue = new CSubPicQueueNoThread(pAllocator, &hr)) || FAILED(hr))
            {
                m_pSubPicQueue = NULL;
                return(false);
            }
        }

        if(m_SubPicProviderId != (DWORD_PTR)(ISubPicProvider*)m_pSubPicProvider)
        {
            m_pSubPicQueue->SetSubPicProvider(m_pSubPicProvider);
            m_SubPicProviderId = (DWORD_PTR)(ISubPicProvider*)m_pSubPicProvider;
        }

        CComPtr<ISubPic> pSubPic;
        if(!m_pSubPicQueue->LookupSubPic(rt, pSubPic))
            return(false);

        CRect r;
        pSubPic->GetDirtyRect(r);

        if(dst.type == MSP_RGB32 || dst.type == MSP_RGB24 || dst.type == MSP_RGB16 || dst.type == MSP_RGB15)
            dst.h = -dst.h;

        pSubPic->AlphaBlt(r, r, &dst);

        return(true);
    }

    DWORD ThreadProc()
    {
        SetThreadPriority(m_hThread, THREAD_PRIORITY_LOWEST);

        CAtlArray<HANDLE> handles;
        handles.Add(GetRequestHandle());

        CString fn = GetFileName();
        CFileStatus fs;
        fs.m_mtime = 0;
        CFileGetStatus(fn, fs);

        while(1)
        {
            DWORD i = WaitForMultipleObjects(handles.GetCount(), handles.GetData(), FALSE, 1000);

            if(WAIT_OBJECT_0 == i)
            {
                Reply(S_OK);
                break;
            }
            else if(WAIT_OBJECT_0 + 1 >= i && i <= WAIT_OBJECT_0 + handles.GetCount())
            {
                if(FindNextChangeNotification(handles[i - WAIT_OBJECT_0]))
                {
                    CFileStatus fs2;
                    fs2.m_mtime = 0;
                    CFileGetStatus(fn, fs2);

                    if(fs.m_mtime < fs2.m_mtime)
                    {
                        fs.m_mtime = fs2.m_mtime;

                        if(CComQIPtr<ISubStream> pSubStream = m_pSubPicProvider)
                        {
                            CAutoLock cAutoLock(&m_csSubLock);
                            pSubStream->Reload();
                        }
                    }
                }
            }
            else if(WAIT_TIMEOUT == i)
            {
                CString fn2 = GetFileName();

                if(fn != fn2)
                {
                    CPath p(fn2);
                    p.RemoveFileSpec();
                    HANDLE h = FindFirstChangeNotification(p, FALSE, FILE_NOTIFY_CHANGE_LAST_WRITE);
                    if(h != INVALID_HANDLE_VALUE)
                    {
                        fn = fn2;
                        handles.SetCount(1);
                        handles.Add(h);
                    }
                }
            }
            else // if(WAIT_ABANDONED_0 == i || WAIT_FAILED == i)
            {
                break;
            }
        }

        m_hThread = 0;

        for(ptrdiff_t i = 1; i < handles.GetCount(); i++)
            FindCloseChangeNotification(handles[i]);

        return 0;
    }
};

class CVobSubFilter : virtual public CFilter
{
public:
    CVobSubFilter(CString fn = _T(""))
    {
        if(!fn.IsEmpty()) Open(fn);
    }

    bool Open(CString fn)
    {
        SetFileName(_T(""));
        m_pSubPicProvider = NULL;

        if(CVobSubFile* vsf = new CVobSubFile(&m_csSubLock))
        {
            m_pSubPicProvider = (ISubPicProvider*)vsf;
            if(vsf->Open(CString(fn))) SetFileName(fn);
            else m_pSubPicProvider = NULL;
        }

        return !!m_pSubPicProvider;
    }
};

class CTextSubFilter : virtual public CFilter
{
    int m_CharSet;

public:
    CTextSubFilter(CString fn = _T(""), int CharSet = DEFAULT_CHARSET, float fps = -1)
        : m_CharSet(CharSet)
    {
        m_fps = fps;
        if(!fn.IsEmpty()) Open(fn, CharSet);
    }

    int GetCharSet()
    {
        return(m_CharSet);
    }

    bool Open(CString fn, int CharSet = DEFAULT_CHARSET)
    {
        SetFileName(_T(""));
        m_pSubPicProvider = NULL;

        if(!m_pSubPicProvider)
        {
            if(ssf::CRenderer* ssf = new ssf::CRenderer(&m_csSubLock))
            {
                m_pSubPicProvider = (ISubPicProvider*)ssf;
                if(ssf->Open(CString(fn))) SetFileName(fn);
                else m_pSubPicProvider = NULL;
            }
        }

        if(!m_pSubPicProvider)
        {
            if(CRenderedTextSubtitle* rts = new CRenderedTextSubtitle(&m_csSubLock))
            {
                m_pSubPicProvider = (ISubPicProvider*)rts;
                if(rts->Open(CString(fn), CharSet)) SetFileName(fn);
                else m_pSubPicProvider = NULL;
            }
        }

        return !!m_pSubPicProvider;
    }
};

//
// VirtualDub new plugin interface sdk 1.1
//
namespace VirtualDubNew
{
#include <vd2\plugin\vdplugin.h>
#include <vd2\plugin\vdvideofilt.h>

class CVirtualDubFilter : virtual public CFilter
{
public:
    CVirtualDubFilter() {}
    virtual ~CVirtualDubFilter() {}

    virtual int RunProc(const VDXFilterActivation* fa, const VDXFilterFunctions* ff)
    {
        SubPicDesc dst;
        dst.type = MSP_RGB32;
        dst.w = fa->src.w;
        dst.h = fa->src.h;
        dst.bpp = 32;
        dst.pitch = fa->src.pitch;
        dst.bits = (LPVOID)fa->src.data;

        Render(dst, 10000i64 * fa->pfsi->lSourceFrameMS, (float)1000 / fa->pfsi->lMicrosecsPerFrame);

        return 0;
    }

    virtual long ParamProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff)
    {
        fa->dst.offset	= fa->src.offset;
        fa->dst.modulo	= fa->src.modulo;
        fa->dst.pitch	= fa->src.pitch;

        return 0;
    }

    virtual int ConfigProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff, VDXHWND hwnd) = 0;
    virtual void StringProc(const VDXFilterActivation* fa, const VDXFilterFunctions* ff, char* str) = 0;
    virtual bool FssProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff, char* buf, int buflen) = 0;
};

class CVobSubVirtualDubFilter : public CVobSubFilter, public CVirtualDubFilter
{
public:
    CVobSubVirtualDubFilter(CString fn = _T(""))
        : CVobSubFilter(fn) {}

    int ConfigProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff, VDXHWND hwnd)
    {
        AFX_MANAGE_STATE(AfxGetStaticModuleState());

        CFileDialog fd(TRUE, NULL, GetFileName(), OFN_EXPLORER | OFN_ENABLESIZING | OFN_HIDEREADONLY,
                       _T("VobSub files (*.idx;*.sub)|*.idx;*.sub||"), CWnd::FromHandle((HWND)hwnd), 0);

        if(fd.DoModal() != IDOK) return 1;

        return Open(fd.GetPathName()) ? 0 : 1;
    }

    void StringProc(const VDXFilterActivation* fa, const VDXFilterFunctions* ff, char* str)
    {
        sprintf(str, " (%s)", !GetFileName().IsEmpty() ? static_cast<const char*>(CStringA(GetFileName())) : " (empty)");
    }

    bool FssProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff, char* buf, int buflen)
    {
        CStringA fn(GetFileName());
        fn.Replace("\\", "\\\\");
        _snprintf(buf, buflen, "Config(\"%s\")", static_cast<const char*>(fn));
        return(true);
    }
};

class CTextSubVirtualDubFilter : public CTextSubFilter, public CVirtualDubFilter
{
public:
    CTextSubVirtualDubFilter(CString fn = _T(""), int CharSet = DEFAULT_CHARSET)
        : CTextSubFilter(fn, CharSet) {}

    int ConfigProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff, VDXHWND hwnd)
    {
        AFX_MANAGE_STATE(AfxGetStaticModuleState());

        /* off encoding changing */
#ifndef _DEBUG
        const TCHAR formats[] = _T("TextSub files (*.sub;*.srt;*.smi;*.ssa;*.ass;*.xss;*.psb;*.txt)|*.sub;*.srt;*.smi;*.ssa;*.ass;*.xss;*.psb;*.txt||");
        CFileDialog fd(TRUE, NULL, GetFileName(), OFN_EXPLORER | OFN_ENABLESIZING | OFN_HIDEREADONLY | OFN_ENABLETEMPLATE | OFN_ENABLEHOOK,
                       formats, CWnd::FromHandle((HWND)hwnd), sizeof(OPENFILENAME));
        //OPENFILENAME_SIZE_VERSION_400 /*0*/);
        UINT_PTR CALLBACK OpenHookProc(HWND hDlg, UINT uiMsg, WPARAM wParam, LPARAM lParam);

        fd.m_pOFN->hInstance = AfxGetResourceHandle();
        fd.m_pOFN->lpTemplateName = MAKEINTRESOURCE(IDD_TEXTSUBOPENTEMPLATE);
        fd.m_pOFN->lpfnHook = (LPOFNHOOKPROC)OpenHookProc;
        fd.m_pOFN->lCustData = (LPARAM)DEFAULT_CHARSET;
#else
        const TCHAR formats[] = _T("TextSub files (*.sub;*.srt;*.smi;*.ssa;*.ass;*.xss;*.psb;*.txt)|*.sub;*.srt;*.smi;*.ssa;*.ass;*.xss;*.psb;*.txt||");
        CFileDialog fd(TRUE, NULL, GetFileName(), OFN_ENABLESIZING | OFN_HIDEREADONLY,
                       formats, CWnd::FromHandle((HWND)hwnd), sizeof(OPENFILENAME));
#endif
        if(fd.DoModal() != IDOK) return 1;

        return Open(fd.GetPathName(), fd.m_pOFN->lCustData) ? 0 : 1;
    }

    void StringProc(const VDXFilterActivation* fa, const VDXFilterFunctions* ff, char* str)
    {
        if(!GetFileName().IsEmpty()) sprintf(str, " (%s, %d)", static_cast<const char*>(CStringA(GetFileName())), GetCharSet());
        else sprintf(str, " (empty)");
    }

    bool FssProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff, char* buf, int buflen)
    {
        CStringA fn(GetFileName());
        fn.Replace("\\", "\\\\");
        _snprintf(buf, buflen, "Config(\"%s\", %d)", static_cast<const char*>(fn), GetCharSet());
        return(true);
    }
};

int vobsubInitProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff)
{
    return !(*(CVirtualDubFilter**)fa->filter_data = new CVobSubVirtualDubFilter());
}

int textsubInitProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff)
{
    return !(*(CVirtualDubFilter**)fa->filter_data = new CTextSubVirtualDubFilter());
}

void baseDeinitProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff)
{
    CVirtualDubFilter* f = *(CVirtualDubFilter**)fa->filter_data;
    if(f) delete f, f = NULL;
}

int baseRunProc(const VDXFilterActivation* fa, const VDXFilterFunctions* ff)
{
    CVirtualDubFilter* f = *(CVirtualDubFilter**)fa->filter_data;
    return f ? f->RunProc(fa, ff) : 1;
}

long baseParamProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff)
{
    CVirtualDubFilter* f = *(CVirtualDubFilter**)fa->filter_data;
    return f ? f->ParamProc(fa, ff) : 1;
}

int baseConfigProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff, VDXHWND hwnd)
{
    CVirtualDubFilter* f = *(CVirtualDubFilter**)fa->filter_data;
    return f ? f->ConfigProc(fa, ff, hwnd) : 1;
}

void baseStringProc(const VDXFilterActivation* fa, const VDXFilterFunctions* ff, char* str)
{
    CVirtualDubFilter* f = *(CVirtualDubFilter**)fa->filter_data;
    if(f) f->StringProc(fa, ff, str);
}

bool baseFssProc(VDXFilterActivation* fa, const VDXFilterFunctions* ff, char* buf, int buflen)
{
    CVirtualDubFilter* f = *(CVirtualDubFilter**)fa->filter_data;
    return f ? f->FssProc(fa, ff, buf, buflen) : false;
}

void vobsubScriptConfig(IVDXScriptInterpreter* isi, void* lpVoid, VDXScriptValue* argv, int argc)
{
    VDXFilterActivation* fa = (VDXFilterActivation*)lpVoid;
    CVirtualDubFilter* f = *(CVirtualDubFilter**)fa->filter_data;
    if(f) delete f;
    f = new CVobSubVirtualDubFilter(CString(*argv[0].asString()));
    *(CVirtualDubFilter**)fa->filter_data = f;
}

void textsubScriptConfig(IVDXScriptInterpreter* isi, void* lpVoid, VDXScriptValue* argv, int argc)
{
    VDXFilterActivation* fa = (VDXFilterActivation*)lpVoid;
    CVirtualDubFilter* f = *(CVirtualDubFilter**)fa->filter_data;
    if(f) delete f;
    f = new CTextSubVirtualDubFilter(CString(*argv[0].asString()), argv[1].asInt());
    *(CVirtualDubFilter**)fa->filter_data = f;
}

VDXScriptFunctionDef vobsub_func_defs[] =
{
    { (VDXScriptFunctionPtr)vobsubScriptConfig, "Config", "0s" },
    { NULL },
};

VDXScriptObject vobsub_obj =
{
    NULL, vobsub_func_defs
};

struct VDXFilterDefinition filterDef_vobsub =
{
    NULL, NULL, NULL,       // next, prev, module
    "VobSub",				// name
    "Adds subtitles from a vob sequence.", // desc
    "Gabest",               // maker
    NULL,                   // private_data
    sizeof(CVirtualDubFilter**), // inst_data_size
    vobsubInitProc,         // initProc
    baseDeinitProc,			// deinitProc
    baseRunProc,			// runProc
    baseParamProc,			// paramProc
    baseConfigProc,			// configProc
    baseStringProc,			// stringProc
    NULL,					// startProc
    NULL,					// endProc
    &vobsub_obj,			// script_obj
    baseFssProc,			// fssProc
};

VDXScriptFunctionDef textsub_func_defs[] =
{
    { (VDXScriptFunctionPtr)textsubScriptConfig, "Config", "0si" },
    { NULL },
};

VDXScriptObject textsub_obj =
{
    NULL, textsub_func_defs
};

struct VDXFilterDefinition filterDef_textsub =
{
    NULL, NULL, NULL,		// next, prev, module
#ifdef _VSMOD
    "TextSubMod",			// name
#else
    "TextSub",				// name
#endif
    "Adds subtitles from srt, sub, psb, smi, ssa, ass file formats.", // desc
#ifdef _VSMOD
    "Teplofizik",			// maker
#else
    "Gabest",				// maker
#endif
    NULL,					// private_data
    sizeof(CVirtualDubFilter**), // inst_data_size
    textsubInitProc,		// initProc
    baseDeinitProc,			// deinitProc
    baseRunProc,			// runProc
    baseParamProc,			// paramProc
    baseConfigProc,			// configProc
    baseStringProc,			// stringProc
    NULL,					// startProc
    NULL,					// endProc
    &textsub_obj,			// script_obj
    baseFssProc,			// fssProc
};

static VDXFilterDefinition* fd_vobsub;
static VDXFilterDefinition* fd_textsub;

extern "C" __declspec(dllexport) int __cdecl VirtualdubFilterModuleInit2(VDXFilterModule *fm, const VDXFilterFunctions *ff, int& vdfd_ver, int& vdfd_compat)
{
    if(!(fd_vobsub = ff->addFilter(fm, &filterDef_vobsub, sizeof(VDXFilterDefinition)))
       || !(fd_textsub = ff->addFilter(fm, &filterDef_textsub, sizeof(VDXFilterDefinition))))
        return 1;

    vdfd_ver = VIRTUALDUB_FILTERDEF_VERSION;
    vdfd_compat = VIRTUALDUB_FILTERDEF_COMPATIBLE;

    return 0;
}

extern "C" __declspec(dllexport) void __cdecl VirtualdubFilterModuleDeinit(VDXFilterModule *fm, const VDXFilterFunctions *ff)
{
    ff->removeFilter(fd_textsub);
    ff->removeFilter(fd_vobsub);
}
}

//
// Avisynth interface
//

namespace AviSynth1
{
#include <avisynth\avisynth1.h>

class CAvisynthFilter : public GenericVideoFilter, virtual public CFilter
{
public:
    CAvisynthFilter(PClip c, IScriptEnvironment* env) : GenericVideoFilter(c) {}

    PVideoFrame __stdcall GetFrame(int n, IScriptEnvironment* env)
    {
        PVideoFrame frame = child->GetFrame(n, env);

        env->MakeWritable(&frame);

        SubPicDesc dst;
        dst.w = vi.width;
        dst.h = vi.height;
        dst.pitch = frame->GetPitch();
        dst.bits = (void**)frame->GetWritePtr();
        dst.bpp = vi.BitsPerPixel();
        dst.type =
            vi.IsRGB32() ? (env->GetVar("RGBA").AsBool() ? MSP_RGBA : MSP_RGB32) :
                vi.IsRGB24() ? MSP_RGB24 :
                vi.IsYUY2() ? MSP_YUY2 :
                -1;

        float fps = m_fps > 0 ? m_fps : (float)vi.fps_numerator / vi.fps_denominator;

        Render(dst, (REFERENCE_TIME)(10000000i64 * n / fps), fps);

        return(frame);
    }
};

class CVobSubAvisynthFilter : public CVobSubFilter, public CAvisynthFilter
{
public:
    CVobSubAvisynthFilter(PClip c, const char* fn, IScriptEnvironment* env)
        : CVobSubFilter(CString(fn))
        , CAvisynthFilter(c, env)
    {
        if(!m_pSubPicProvider)
            env->ThrowError("VobSub: Can't open \"%s\"", fn);
    }
};

AVSValue __cdecl VobSubCreateS(AVSValue args, void* user_data, IScriptEnvironment* env)
{
    return(new CVobSubAvisynthFilter(args[0].AsClip(), args[1].AsString(), env));
}

class CTextSubAvisynthFilter : public CTextSubFilter, public CAvisynthFilter
{
public:
    CTextSubAvisynthFilter(PClip c, IScriptEnvironment* env, const char* fn, int CharSet = DEFAULT_CHARSET, float fps = -1)
        : CTextSubFilter(CString(fn), CharSet, fps)
        , CAvisynthFilter(c, env)
    {
        if(!m_pSubPicProvider)
#ifdef _VSMOD
            env->ThrowError("TextSubMod: Can't open \"%s\"", fn);
#else
            env->ThrowError("TextSub: Can't open \"%s\"", fn);
#endif
    }
};

AVSValue __cdecl TextSubCreateS(AVSValue args, void* user_data, IScriptEnvironment* env)
{
    return(new CTextSubAvisynthFilter(args[0].AsClip(), env, args[1].AsString()));
}

AVSValue __cdecl TextSubCreateSI(AVSValue args, void* user_data, IScriptEnvironment* env)
{
    return(new CTextSubAvisynthFilter(args[0].AsClip(), env, args[1].AsString(), args[2].AsInt()));
}

AVSValue __cdecl TextSubCreateSIF(AVSValue args, void* user_data, IScriptEnvironment* env)
{
    return(new CTextSubAvisynthFilter(args[0].AsClip(), env, args[1].AsString(), args[2].AsInt(), args[3].AsFloat()));
}

AVSValue __cdecl MaskSubCreateSIIFI(AVSValue args, void* user_data, IScriptEnvironment* env)
{
    AVSValue rgb32("RGB32");
    AVSValue  tab[5] =
    {
        args[1],
        args[2],
        args[3],
        args[4],
        rgb32
    };
    AVSValue value(tab, 5);
    const char * nom[5] =
    {
        "width",
        "height",
        "fps",
        "length",
        "pixel_type"
    };
    AVSValue clip(env->Invoke("Blackness", value, nom));
    env->SetVar(env->SaveString("RGBA"), true);
    return(new CTextSubAvisynthFilter(clip.AsClip(), env, args[0].AsString()));
}

extern "C" __declspec(dllexport) const char* __stdcall AvisynthPluginInit(IScriptEnvironment* env)
{
    env->AddFunction("VobSub", "cs", VobSubCreateS, 0);
#ifdef _VSMOD
    env->AddFunction("TextSubMod", "cs", TextSubCreateS, 0);
    env->AddFunction("TextSubMod", "csi", TextSubCreateSI, 0);
    env->AddFunction("TextSubMod", "csif", TextSubCreateSIF, 0);
    env->AddFunction("MaskSubMod", "siifi", MaskSubCreateSIIFI, 0);
#else
    env->AddFunction("TextSub", "cs", TextSubCreateS, 0);
    env->AddFunction("TextSub", "csi", TextSubCreateSI, 0);
    env->AddFunction("TextSub", "csif", TextSubCreateSIF, 0);
    env->AddFunction("MaskSub", "siifi", MaskSubCreateSIIFI, 0);
#endif
    env->SetVar(env->SaveString("RGBA"), false);
    return(NULL);
}
}

namespace AviSynth25
{
#include <avisynth\avisynth25.h>

static bool s_fSwapUV = false;

class CAvisynthFilter : public GenericVideoFilter, virtual public CFilter
{
public:
    VFRTranslator *vfr;

    CAvisynthFilter(PClip c, IScriptEnvironment* env, VFRTranslator *_vfr = 0) : GenericVideoFilter(c), vfr(_vfr) {}

    PVideoFrame __stdcall GetFrame(int n, IScriptEnvironment* env)
    {
        PVideoFrame frame = child->GetFrame(n, env);

        env->MakeWritable(&frame);

        SubPicDesc dst;
        dst.w = vi.width;
        dst.h = vi.height;
        dst.pitch = frame->GetPitch();
        dst.pitchUV = frame->GetPitch(PLANAR_U);
        dst.bits = (void**)frame->GetWritePtr();
        dst.bitsU = frame->GetWritePtr(PLANAR_U);
        dst.bitsV = frame->GetWritePtr(PLANAR_V);
        dst.bpp = dst.pitch / dst.w * 8; //vi.BitsPerPixel();
        dst.type =
            vi.IsRGB32() ? (env->GetVar("RGBA").AsBool() ? MSP_RGBA : MSP_RGB32)  :
                vi.IsRGB24() ? MSP_RGB24 :
                vi.IsYUY2() ? MSP_YUY2 :
        /*vi.IsYV12()*/ vi.pixel_type == VideoInfo::CS_YV12 ? (s_fSwapUV ? MSP_IYUV : MSP_YV12) :
        /*vi.IsIYUV()*/ vi.pixel_type == VideoInfo::CS_IYUV ? (s_fSwapUV ? MSP_YV12 : MSP_IYUV) :
                -1;

        float fps = m_fps > 0 ? m_fps : (float)vi.fps_numerator / vi.fps_denominator;

        REFERENCE_TIME timestamp;

        if(!vfr)
            timestamp = (REFERENCE_TIME)(10000000i64 * n / fps);
        else
            timestamp = (REFERENCE_TIME)(10000000 * vfr->TimeStampFromFrameNumber(n));

        Render(dst, timestamp, fps);

        return(frame);
    }
};

class CVobSubAvisynthFilter : public CVobSubFilter, public CAvisynthFilter
{
public:
    CVobSubAvisynthFilter(PClip c, const char* fn, IScriptEnvironment* env)
        : CVobSubFilter(CString(fn))
        , CAvisynthFilter(c, env)
    {
        if(!m_pSubPicProvider)
            env->ThrowError("VobSub: Can't open \"%s\"", fn);
    }
};

AVSValue __cdecl VobSubCreateS(AVSValue args, void* user_data, IScriptEnvironment* env)
{
    return(new CVobSubAvisynthFilter(args[0].AsClip(), args[1].AsString(), env));
}

class CTextSubAvisynthFilter : public CTextSubFilter, public CAvisynthFilter
{
public:
    CTextSubAvisynthFilter(PClip c, IScriptEnvironment* env, const char* fn, int CharSet = DEFAULT_CHARSET, float fps = -1, VFRTranslator *vfr = 0) //vfr patch
        : CTextSubFilter(CString(fn), CharSet, fps)
        , CAvisynthFilter(c, env, vfr)
    {
        if(!m_pSubPicProvider)
#ifdef _VSMOD
            env->ThrowError("TextSubMod: Can't open \"%s\"", fn);
#else
            env->ThrowError("TextSub: Can't open \"%s\"", fn);
#endif
    }
};

AVSValue __cdecl TextSubCreateGeneral(AVSValue args, void* user_data, IScriptEnvironment* env)
{
    if(!args[1].Defined())
#ifdef _VSMOD
        env->ThrowError("TextSubMod: You must specify a subtitle file to use");
#else
        env->ThrowError("TextSub: You must specify a subtitle file to use");
#endif
    VFRTranslator *vfr = 0;
    if(args[4].Defined())
        vfr = GetVFRTranslator(args[4].AsString());

    return(new CTextSubAvisynthFilter(
               args[0].AsClip(),
               env,
               args[1].AsString(),
               args[2].AsInt(DEFAULT_CHARSET),
               args[3].AsFloat(-1),
               vfr));
}

AVSValue __cdecl TextSubSwapUV(AVSValue args, void* user_data, IScriptEnvironment* env)
{
    s_fSwapUV = args[0].AsBool(false);
    return(AVSValue());
}

AVSValue __cdecl MaskSubCreate(AVSValue args, void* user_data, IScriptEnvironment* env)/*SIIFI*/
{
    if(!args[0].Defined())
#ifdef _VSMOD
        env->ThrowError("MaskSubMod: You must specify a subtitle file to use");
#else
        env->ThrowError("MaskSub: You must specify a subtitle file to use");
#endif
    if(!args[3].Defined() && !args[6].Defined())
#ifdef _VSMOD
        env->ThrowError("MaskSubMod: You must specify either FPS or a VFR timecodes file");
#else
        env->ThrowError("MaskSub: You must specify either FPS or a VFR timecodes file");
#endif
    VFRTranslator *vfr = 0;
    if(args[6].Defined())
        vfr = GetVFRTranslator(args[6].AsString());

    AVSValue rgb32("RGB32");
    AVSValue fps(args[3].AsFloat(25));
    AVSValue  tab[6] =
    {
        args[1],
        args[2],
        args[3],
        args[4],
        rgb32
    };
    AVSValue value(tab, 5);
    const char * nom[5] =
    {
        "width",
        "height",
        "fps",
        "length",
        "pixel_type"
    };
    AVSValue clip(env->Invoke("Blackness", value, nom));
    env->SetVar(env->SaveString("RGBA"), true);
    //return(new CTextSubAvisynthFilter(clip.AsClip(), env, args[0].AsString()));
    return(new CTextSubAvisynthFilter(
               clip.AsClip(),
               env,
               args[0].AsString(),
               args[5].AsInt(DEFAULT_CHARSET),
               args[3].AsFloat(-1),
               vfr));
}

extern "C" __declspec(dllexport) const char* __stdcall AvisynthPluginInit2(IScriptEnvironment* env)
{
    env->AddFunction("VobSub", "cs", VobSubCreateS, 0);
#ifdef _VSMOD
    env->AddFunction("TextSubMod", "c[file]s[charset]i[fps]f[vfr]s", TextSubCreateGeneral, 0);
    env->AddFunction("TextSubModSwapUV", "b", TextSubSwapUV, 0);
    env->AddFunction("MaskSubMod", "[file]s[width]i[height]i[fps]f[length]i[charset]i[vfr]s", MaskSubCreate, 0);
#else
    env->AddFunction("TextSub", "c[file]s[charset]i[fps]f[vfr]s", TextSubCreateGeneral, 0);
    env->AddFunction("TextSubSwapUV", "b", TextSubSwapUV, 0);
    env->AddFunction("MaskSub", "[file]s[width]i[height]i[fps]f[length]i[charset]i[vfr]s", MaskSubCreate, 0);
#endif
    env->SetVar(env->SaveString("RGBA"), false);
    return(NULL);
}
}

//
// VapourSynth interface
//

#include <emmintrin.h>

namespace VapourSynth {
#include <VapourSynth.h>
#include <VSHelper.h>

    class CTextSubVapourSynthFilter : public CTextSubFilter {
    public:
        CTextSubVapourSynthFilter(const char * file, const int charset, const float fps, int * error) : CTextSubFilter(CString(file), charset, fps) {
            *error = !m_pSubPicProvider ? 1 : 0;
        }
    };

    class CVobSubVapourSynthFilter : public CVobSubFilter {
    public:
        CVobSubVapourSynthFilter(const char * file, int * error) : CVobSubFilter(CString(file)) {
            *error = !m_pSubPicProvider ? 1 : 0;
        }
    };

    struct VSFilterData {
        VSNodeRef* node;
        const VSVideoInfo * vi;
        float fps;
        VFRTranslator * vfr;
        CTextSubVapourSynthFilter * textsub;
        CVobSubVapourSynthFilter * vobsub;
        bool accurate16bit;
    };

    static void VS_CC vsfilterInit(VSMap *in, VSMap *out, void **instanceData, VSNode *node, VSCore *core, const VSAPI *vsapi) {
        VSFilterData * d = static_cast<VSFilterData *>(*instanceData);
        vsapi->setVideoInfo(d->vi, 1, node);
    }

	class VSFFrameBuf
	{
	protected:
		VSFFrameBuf()
            : subpic{}
            , subpic2{}
        {
        }

	public:
		virtual ~VSFFrameBuf() {}
		virtual void WriteTo(VSFrameRef* frame) = 0;
		SubPicDesc subpic;
        SubPicDesc subpic2;

	private:
		VSFFrameBuf(const VSFFrameBuf*) = delete;
		VSFFrameBuf* operator = (const VSFFrameBuf*) = delete;
	};

	template<int BITDEPTH>
	class VSFYUVBuf : public VSFFrameBuf
	{
		uint8_t* Buffer;

		uint8_t* BufDatas[3];
		uint8_t* BufDatas2[3]; 
		int BufStrides[3];

		const VSAPI* api;
		const VSFilterData* d;

		template<int BC>
		static inline void SplitBits(int sampleCount, const uint16_t* src, uint8_t* dst1, uint8_t* dst2)
		{
			auto srcEnd = src + sampleCount;
			auto sse2End = src + sampleCount - 8;
			if (uintptr_t(src) & 0xf)
				sse2End = src;

			__m128i lomask = _mm_set1_epi16(0xff00i16);
			while (src <= sse2End)
			{
				__m128i buf = _mm_load_si128((const __m128i*)src);
				__m128i hi, lo;

				if (BC == 16)
				{
					hi = _mm_srli_epi16(buf, 8);
					hi = _mm_packus_epi16(hi, hi);
					lo = _mm_and_si128(buf, lomask);
					lo = _mm_packus_epi16(lo, lo);
				}
				else if (BC == 10)
				{
					hi = _mm_srli_epi16(buf, 2);
					hi = _mm_packus_epi16(hi, hi);
					lo = _mm_slli_epi16(buf, 6);
					lo = _mm_and_si128(lo, lomask);
					lo = _mm_packus_epi16(lo, lo);
				}
				_mm_storel_epi64((__m128i*)dst1, hi);
				_mm_storel_epi64((__m128i*)dst2, lo);
				dst1 += 8;
				dst2 += 8;
				src += 8;
			}

			while (src < srcEnd)
			{
				if (BITDEPTH == 10)
				{
					*dst1 = ((*src) >> 2) & 0xff;
					*dst2 = ((*src) << 6) & 0xff;
				}
				else if (BITDEPTH == 16)
				{
					*dst1 = ((*src) >> 8) & 0xff;
					*dst2 = (*src) & 0xff;
				}

				dst1 += 1;
				dst2 += 1;
				src += 1;
			}
		}

		template<int BC>
		static inline void MergeBits(int sampleCount, uint16_t* dst, const uint8_t* src1, const uint8_t* src2)
		{
			auto srcEnd = dst + sampleCount;
			auto sse2End = dst + sampleCount - 8;
			if (uintptr_t(dst) & 0xf)
				sse2End = dst;

			while (dst < sse2End)
			{
				__m128i hbuf = _mm_loadl_epi64((const __m128i*) src1);
				__m128i lbuf = _mm_loadl_epi64((const __m128i*) src2);
				hbuf = _mm_unpacklo_epi8(hbuf, _mm_setzero_si128());
				hbuf = _mm_slli_epi16(hbuf, 8);
				lbuf = _mm_unpacklo_epi8(lbuf, _mm_setzero_si128());
				hbuf = _mm_adds_epi16(hbuf, lbuf);
				if (BC == 10)
					hbuf = _mm_srli_epi16(hbuf, 6);

				_mm_store_si128((__m128i*)dst, hbuf);
				src1 += 8;
				src2 += 8;
				dst += 8;
			}

			while (dst < srcEnd)
			{
				*dst = (*src1 << 8) | *src2;
				if (BC == 10)
					*dst >>= 6;
				src1 += 1;
				src2 += 1;
				dst += 1;
			}
		}

	public:
		~VSFYUVBuf()
		{
			if (Buffer)
				free(Buffer);
		}

		VSFYUVBuf(const VSAPI* api, VSCore *core, const VSFilterData* d, const VSFrameRef* frame)
			: api(api), d(d)
		{
			int totalSize = 0;
			for (int i = 0; i < 3; ++i)
			{
				BufStrides[i] = api->getStride(frame, i);
				totalSize += BufStrides[i] * d->vi->height / (i == 0 ? 1 : 2);
			}
			Buffer = (uint8_t*)malloc(totalSize);

			if (BITDEPTH <= 8)
			{
				BufDatas[0] = Buffer;
				BufDatas[1] = BufDatas[0] + BufStrides[0] * d->vi->height;
				BufDatas[2] = BufDatas[1] + BufStrides[1] * d->vi->height / 2;

				for (int i = 0; i < 3; ++i)
				{
					const uint8_t* p = api->getReadPtr(frame, i);
					memcpy(BufDatas[i], p, api->getStride(frame, i) * d->vi->height / (i == 0 ? 1 : 2));
				}
			}
			else
			{
				for (int i = 0; i < 3; ++i)
					BufStrides[i] /= 2;

				BufDatas[0] = Buffer;
				BufDatas[1] = BufDatas[0] + BufStrides[0] * d->vi->height;
				BufDatas[2] = BufDatas[1] + BufStrides[1] * d->vi->height / 2;
				BufDatas2[0] = BufDatas[2] + BufStrides[2] * d->vi->height / 2;
				BufDatas2[1] = BufDatas2[0] + BufStrides[0] * d->vi->height;
				BufDatas2[2] = BufDatas2[1] + BufStrides[1] * d->vi->height / 2;

				for (int i = 0; i < 3; ++i)
				{
					const uint8_t* p = api->getReadPtr(frame, i);
					int srcStride = api->getStride(frame, i);

					int wEnd = d->vi->width / (i == 0 ? 1 : 2);
					int hEnd = d->vi->height / (i == 0 ? 1 : 2);
					uint8_t* pDst = BufDatas[i];
					uint8_t* pDst2 = BufDatas2[i];

					for (int h = 0; h < hEnd; ++h)
					{
						const uint16_t* pSample = reinterpret_cast<const uint16_t*>(p + h * srcStride);
						uint8_t* pDstSample = BufDatas[i] + h * BufStrides[i];
						uint8_t* pDstSample2 = BufDatas2[i] + h * BufStrides[i];
						SplitBits<BITDEPTH>(wEnd, pSample, pDstSample, pDstSample2);
					}
				}
			}

			subpic.w = d->vi->width;
			subpic.h = d->vi->height;
			subpic.pitch = BufStrides[0];
			subpic.pitchUV = BufStrides[1];
			subpic.bits = BufDatas[0];
			subpic.bitsU = BufDatas[1];
			subpic.bitsV = BufDatas[2];
			subpic.bpp = 8;
			subpic.type = MSP_YV12;

            if (BITDEPTH > 8)
            {
                subpic2.w = d->vi->width;
                subpic2.h = d->vi->height;
                subpic2.pitch = BufStrides[0];
                subpic2.pitchUV = BufStrides[1];
                subpic2.bits = BufDatas2[0];
                subpic2.bitsU = BufDatas2[1];
                subpic2.bitsV = BufDatas2[2];
                subpic2.bpp = 8;
                subpic2.type = MSP_YV12;
            }
		}

		void WriteTo(VSFrameRef* frame) override
		{
			if (BITDEPTH <= 8)
			{
				for (int i = 0; i < 3; ++i)
				{
					int dstStride = api->getStride(frame, i);
					uint8_t* pDst = api->getWritePtr(frame, i);
					int srcStride = BufStrides[i];
					const uint8_t* pSrc = BufDatas[i];
					int wEnd = d->vi->width / (i == 0 ? 1 : 2);
					int hEnd = d->vi->height / (i == 0 ? 1 : 2);
					for (int h = 0; h < hEnd; ++h)
					{
						uint8_t* pDstRow = pDst + h * dstStride;
						const uint8_t* pSrcRow = pSrc + h * srcStride;
						memcpy(pDstRow, pSrcRow, wEnd);
					}
				}
			}
			else
			{
				for (int i = 0; i < 3; ++i)
				{
					int dstStride = api->getStride(frame, i);
					uint8_t* pDst = api->getWritePtr(frame, i);
					int srcStride = BufStrides[i];
					const uint8_t* pSrc = BufDatas[i];
					const uint8_t* pSrc2 = BufDatas2[i];
					int wEnd = d->vi->width / (i == 0 ? 1 : 2);
					int hEnd = d->vi->height / (i == 0 ? 1 : 2);
					for (int h = 0; h < hEnd; ++h)
					{
						uint16_t* pDstSample = reinterpret_cast<uint16_t*>(pDst + h * dstStride);
						const uint8_t* pSrcSample = pSrc + h * srcStride;
						const uint8_t* pSrcSample2 = pSrc2 + h * srcStride;

						MergeBits<BITDEPTH>(wEnd, pDstSample, pSrcSample, pSrcSample2);
					}
				}
			}
		}
	};

	class VSFRGBBuf : public VSFFrameBuf
	{
		VSFrameRef* tmp;
		const VSAPI* api;
		const VSFilterData* d;

	public:
		~VSFRGBBuf()
		{
			if (tmp)
				api->freeFrame(tmp);
		}

		VSFRGBBuf(const VSAPI* api, VSCore *core, const VSFilterData* d, const VSFrameRef* frame)
			: api(api), d(d)
		{
			tmp = api->newVideoFrame(api->getFormatPreset(pfCompatBGR32, core), d->vi->width, d->vi->height, nullptr, core);

			const int srcStride = api->getStride(frame, 0);
			const int tmpStride = api->getStride(tmp, 0);
			const uint8_t * srcpR = api->getReadPtr(frame, 0);
			const uint8_t * srcpG = api->getReadPtr(frame, 1);
			const uint8_t * srcpB = api->getReadPtr(frame, 2);
			uint8_t * VS_RESTRICT tmpp = api->getWritePtr(tmp, 0);

			tmpp += tmpStride * (d->vi->height - 1);

			for (int y = 0; y < d->vi->height; y++) {
				for (int x = 0; x < d->vi->width; x++) {
					tmpp[x * 4] = srcpB[x];
					tmpp[x * 4 + 1] = srcpG[x];
					tmpp[x * 4 + 2] = srcpR[x];
					tmpp[x * 4 + 3] = 0ui8;
				}

				srcpR += srcStride;
				srcpG += srcStride;
				srcpB += srcStride;
				tmpp -= tmpStride;
			}

			subpic.w = d->vi->width;
			subpic.h = d->vi->height;
			subpic.pitch = tmpStride;
			subpic.bits = api->getWritePtr(tmp, 0);
			subpic.bpp = 32;
			subpic.type = MSP_RGB32;
		}

		void WriteTo(VSFrameRef* frame) override
		{
			const int tmpStride = api->getStride(tmp, 0);
			const int dstStride = api->getStride(frame, 0);
			const uint8_t * tmpp = api->getReadPtr(tmp, 0);
			uint8_t * VS_RESTRICT dstpR = api->getWritePtr(frame, 0);
			uint8_t * VS_RESTRICT dstpG = api->getWritePtr(frame, 1);
			uint8_t * VS_RESTRICT dstpB = api->getWritePtr(frame, 2);

			tmpp += tmpStride * (d->vi->height - 1);

			for (int y = 0; y < d->vi->height; y++) {
				for (int x = 0; x < d->vi->width; x++) {
					dstpB[x] = tmpp[x * 4];
					dstpG[x] = tmpp[x * 4 + 1];
					dstpR[x] = tmpp[x * 4 + 2];
				}

				tmpp -= tmpStride;
				dstpR += dstStride;
				dstpG += dstStride;
				dstpB += dstStride;
			}
		}
	};

    static const VSFrameRef *VS_CC vsfilterGetFrame(int n, int activationReason, void **instanceData, void **frameData, VSFrameContext *frameCtx, VSCore *core, const VSAPI *vsapi) {
        const VSFilterData * d = static_cast<const VSFilterData *>(*instanceData);

        if (activationReason == arInitial) {
            vsapi->requestFrameFilter(n, d->node, frameCtx);
        } else if (activationReason == arAllFramesReady) {
            const VSFrameRef * src = vsapi->getFrameFilter(n, d->node, frameCtx);
            VSFrameRef * dst = vsapi->copyFrame(src, core);

			std::unique_ptr<VSFFrameBuf> frameBuf;

			if (d->vi->format->colorFamily == cmRGB)
			{
				frameBuf.reset(new VSFRGBBuf(vsapi, core, d, src));
			}
			else if (d->vi->format->colorFamily == cmYUV)
			{
				if (d->vi->format->id == pfYUV420P8)
					frameBuf.reset(new VSFYUVBuf<8>(vsapi, core, d, src));
				else if (d->vi->format->id == pfYUV420P10)
					frameBuf.reset(new VSFYUVBuf<10>(vsapi, core, d, src));
				else if (d->vi->format->id == pfYUV420P16)
					frameBuf.reset(new VSFYUVBuf<16>(vsapi, core, d, src));
			}

			if (frameBuf)
			{
				REFERENCE_TIME timestamp;
				if (!d->vfr)
					timestamp = static_cast<REFERENCE_TIME>(10000000i64 * n / d->fps);
				else
					timestamp = static_cast<REFERENCE_TIME>(10000000 * d->vfr->TimeStampFromFrameNumber(n));

                if (d->textsub)
                {
                    d->textsub->Render(frameBuf->subpic, timestamp, d->fps);
                    if (d->accurate16bit && frameBuf->subpic2.bits)
                        d->textsub->Render(frameBuf->subpic2, timestamp, d->fps);
                }
                else
                {
                    d->vobsub->Render(frameBuf->subpic, timestamp, d->fps);
                    if (d->accurate16bit && frameBuf->subpic2.bits)
                        d->vobsub->Render(frameBuf->subpic2, timestamp, d->fps);
                }

				frameBuf->WriteTo(dst);
			}

			vsapi->freeFrame(src);
			return dst;
        }

        return nullptr;
    }

    static void VS_CC vsfilterFree(void *instanceData, VSCore *core, const VSAPI *vsapi) {
        VSFilterData * d = static_cast<VSFilterData *>(instanceData);

        vsapi->freeNode(d->node);

        delete d->textsub;
        delete d->vobsub;

        delete d;
    }

    static void VS_CC vsfilterCreate(const VSMap *in, VSMap *out, void *userData, VSCore *core, const VSAPI *vsapi) {
        std::unique_ptr<VSFilterData> ud(new VSFilterData{});
        VSFilterData& d = *ud;
        int err;

		const ::std::string filterName{ static_cast<const char *>(userData) };

        d.node = vsapi->propGetNode(in, "clip", 0, nullptr);
        d.vi = vsapi->getVideoInfo(d.node);

        if (!isConstantFormat(d.vi) || (d.vi->format->id != pfYUV420P8 && d.vi->format->id != pfRGB24 
			&& d.vi->format->id != pfYUV420P10 && d.vi->format->id != pfYUV420P16)) {
            vsapi->setError(out, (filterName + ": only constant format YUV420P8, YUV420P10, YUV420P16 and RGB24 input supported").c_str());
            vsapi->freeNode(d.node);
            return;
        }

        std::string strfile;
        const char * file = vsapi->propGetData(in, "file", 0, nullptr);
        if (!file) file = "";

        CA2WEX<> utf8file(file, CP_UTF8);
        if (PathFileExistsW(utf8file))
        {
            strfile = CW2AEX<>(utf8file, CP_ACP);
            file = strfile.c_str();
        }

        int charset = int64ToIntS(vsapi->propGetInt(in, "charset", 0, &err));
        if (err)
            charset = DEFAULT_CHARSET;

        float fps = static_cast<float>(vsapi->propGetFloat(in, "fps", 0, &err));
        if (err)
            fps = -1.f;
        d.fps = (fps > 0.f || !d.vi->fpsNum) ? fps : static_cast<float>(d.vi->fpsNum) / d.vi->fpsDen;

        const char * vfr = vsapi->propGetData(in, "vfr", 0, &err);
        if (!err)
            d.vfr = GetVFRTranslator(vfr);

        if (!d.vi->fpsNum && fps <= 0.f && !d.vfr) {
            vsapi->setError(out, (filterName + ": variable framerate clip must have fps or vfr specified").c_str());
            vsapi->freeNode(d.node);
            return;
        }

        if (filterName == "TextSubMod")
            d.textsub = new CTextSubVapourSynthFilter { file, charset, fps, &err };
        else
            d.vobsub = new CVobSubVapourSynthFilter { file, &err };
        if (err) {
            vsapi->setError(out, (filterName + ": can't open " + file).c_str());
            vsapi->freeNode(d.node);
            delete d.textsub;
            delete d.vobsub;
            return;
        }

        d.accurate16bit = vsapi->propGetInt(in, "accurate", 0, &err) != 0;
        if (err)
            d.accurate16bit = false;

        vsapi->createFilter(in, out, static_cast<const char *>(userData), vsfilterInit, vsfilterGetFrame, vsfilterFree, fmParallelRequests, 0, ud.release(), core);
    }

    //////////////////////////////////////////
    // Init

    VS_EXTERNAL_API(void) VapourSynthPluginInit(VSConfigPlugin configFunc, VSRegisterFunction registerFunc, VSPlugin *plugin) {
        configFunc("com.holywu.vsfiltermod", "vsfm", "VSFilterMod", VAPOURSYNTH_API_VERSION, 1, plugin);
        registerFunc("TextSubMod",
                     "clip:clip;"
                     "file:data;"
                     "charset:int:opt;"
                     "fps:float:opt;"
                     "vfr:data:opt;"
                     "accurate:int:opt;",
                     vsfilterCreate, const_cast<char *>("TextSubMod"), plugin);
        registerFunc("VobSub",
                     "clip:clip;"
                     "file:data;"
                     "accurate:int:opt;",
                     vsfilterCreate, const_cast<char *>("VobSub"), plugin);
    }
}

}

UINT_PTR CALLBACK OpenHookProc(HWND hDlg, UINT uiMsg, WPARAM wParam, LPARAM lParam)
{
    switch(uiMsg)
    {
    case WM_NOTIFY:
    {
        OPENFILENAME* ofn = ((OFNOTIFY *)lParam)->lpOFN;

        if(((NMHDR *)lParam)->code == CDN_FILEOK)
        {
            ofn->lCustData = (LPARAM)CharSetList[SendMessage(GetDlgItem(hDlg, IDC_COMBO1), CB_GETCURSEL, 0, 0)];
        }

        break;
    }

    case WM_INITDIALOG:
    {
#ifdef _WIN64
        SetWindowLongPtr(hDlg, GWLP_USERDATA, lParam);
#else
        SetWindowLongPtr(hDlg, GWL_USERDATA, lParam);
#endif

        for(ptrdiff_t i = 0; i < CharSetLen; i++)
        {
            CString s;
            s.Format(_T("%s (%d)"), CharSetNames[i], CharSetList[i]);
            SendMessage(GetDlgItem(hDlg, IDC_COMBO1), CB_ADDSTRING, 0, (LONG)(LPCTSTR)s);
            if(CharSetList[i] == (int)((OPENFILENAME*)lParam)->lCustData)
                SendMessage(GetDlgItem(hDlg, IDC_COMBO1), CB_SETCURSEL, i, 0);
        }

        break;
    }

    default:
        break;
    }

    return FALSE;
}
