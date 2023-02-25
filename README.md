I can spare little energy on this repository so please
# Check here for newer releases:
https://github.com/sorayuki/VSFilterMod/network

---

Usage
=====

    vsfm.TextSubMod(clip clip, string file[, int charset=1, float fps=-1.0, string vfr='', int accurate=0])
    vsfm.VobSub(clip clip, string file)

* clip: Clip to process. Only YUV420P8, YUV420P10, YUV420P16 and RGB24 are supported.
* accurate: 1: enable accurate render for 10/16bit (~2x slower). / 0: disable (default)

Knowing Issues
=====
* Opentype font (such as Source Han Sans) has a much smaller size when displayed vertically (used like @Source Han Sans). (subtitle renders which origin from VSFilter use GDI to render fonts, but GDI performs badly on opentype fonts.)

Use VSFilterMod in MPC-BE
====
1. run `regsvr32.exe VSFilterMod.dll` with administrator privileges
2. Select "VSFilter/xy-VSFilter" on the select of Options/Subtitles/Subtitle renderer
