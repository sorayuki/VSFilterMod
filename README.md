Usage
=====

    vsfm.TextSubMod(clip clip, string file[, int charset=1, float fps=-1.0, string vfr='', int accurate=0])
    vsfm.VobSub(clip clip, string file)

* clip: Clip to process. Only YUV420P8, YUV420P10, YUV420P16 and RGB24 are supported.
* accurate: 1: enable accurate render for 10/16bit (~2x slower). / 0: disable (default)