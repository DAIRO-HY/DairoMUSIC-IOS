//
//  AudioSpectrum.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/19.
//

import AVFoundation
import Accelerate
import MediaToolbox

/// 正在播放的歌曲的实时频谱,播放页的环形波形用
/// 在AVPlayerItem的音频上接一个处理节点(MTAudioProcessingTap)取PCM数据,用Accelerate做FFT,按对数频率分成若干频段
/// 只有播放页的封面页显示时才计算(isEnabled),其他时候处理节点只是把声音原样传过去
final class AudioSpectrum {

    static let shared = AudioSpectrum()

    /// 频段数,从低音到高音按对数频率划分
    static let BAND_COUNT = 64

    /// 时域波形的点数,每次FFT的采样平均成这么多个点(示波器样式用)
    static let WAVE_COUNT = 128

    /// 每次FFT的采样数
    private static let FFT_SIZE = 1024

    /// FFT_SIZE的以2为底的对数
    private static let LOG2N: vDSP_Length = 10

    /// 频段的最低、最高频率(Hz)
    private static let MIN_FREQ: Float = 40
    private static let MAX_FREQ: Float = 16000

    /// 频段强度从分贝换算成0到1:低于这个分贝为0,往上DB_RANGE分贝为1
    private static let MIN_DB: Float = -62
    private static let DB_RANGE: Float = 52

    /// 高音能量比低音低很多,从低到高最多补偿的分贝,波形左右两侧看起来更均匀
    private static let HIGH_BOOST_DB: Float = 8

    private let fftSetup = vDSP_create_fftsetup(AudioSpectrum.LOG2N, FFTRadix(kFFTRadix2))!

    /// 汉宁窗,减少频谱泄漏
    private var window = [Float](repeating: 0, count: AudioSpectrum.FFT_SIZE)

    /// 累积的采样(单声道),攒够FFT_SIZE个计算一次
    private var samples = [Float](repeating: 0, count: AudioSpectrum.FFT_SIZE)
    private var sampleCount = 0

    /// 当前音频的格式,处理节点准备好时更新
    private var format = AudioStreamBasicDescription()

    /// 最新的频段强度,音频线程写,界面线程读
    private var bands = [Float](repeating: 0, count: AudioSpectrum.BAND_COUNT)

    /// 最新的时域波形(-1到1),音频线程写,界面线程读
    private var wave = [Float](repeating: 0, count: AudioSpectrum.WAVE_COUNT)
    private let lock = NSLock()

    /// 是否计算频谱,播放页的封面页显示时打开
    private var enabled = false

    private init() {
        vDSP_hann_window(&self.window, vDSP_Length(AudioSpectrum.FFT_SIZE), Int32(vDSP_HANN_NORM))
    }

    /// 是否计算频谱,关闭时频段强度清零
    var isEnabled: Bool {
        get{
            self.lock.lock()
            defer{ self.lock.unlock() }
            return self.enabled
        }
        set{
            self.lock.lock()
            self.enabled = newValue
            if !newValue{
                self.bands = [Float](repeating: 0, count: AudioSpectrum.BAND_COUNT)
                self.wave = [Float](repeating: 0, count: AudioSpectrum.WAVE_COUNT)
            }
            self.lock.unlock()
        }
    }

    /// 最新的频段强度(0到1),从低音到高音
    var latestBands: [Float] {
        self.lock.lock()
        defer{ self.lock.unlock() }
        return self.bands
    }

    /// 最新的时域波形(-1到1),一次FFT的采样平均成WAVE_COUNT个点
    var latestWave: [Float] {
        self.lock.lock()
        defer{ self.lock.unlock() }
        return self.wave
    }

    /// 给歌曲接上处理节点,音频轨道加载完成之后才能接
    func attach(to item: AVPlayerItem) {
        Task{ @MainActor in
            guard let track = try? await item.asset.loadTracks(withMediaType: .audio).first, let tap = self.createTap() else{
                return
            }
            let params = AVMutableAudioMixInputParameters(track: track)
            params.audioTapProcessor = tap
            let mix = AVMutableAudioMix()
            mix.inputParameters = [params]
            item.audioMix = mix
        }
    }

    /// 创建处理节点,回调里通过storage拿到当前对象(单例,不会被释放)
    private func createTap() -> MTAudioProcessingTap? {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(self).toOpaque(),
            init: { _, clientInfo, storageOut in
                storageOut.pointee = clientInfo
            },
            finalize: nil,
            prepare: { tap, _, format in
                AudioSpectrum.from(tap).prepare(format.pointee)
            },
            unprepare: nil,
            process: { tap, frames, _, bufferList, framesOut, flagsOut in
                guard MTAudioProcessingTapGetSourceAudio(tap, frames, bufferList, flagsOut, nil, framesOut) == noErr else{
                    return
                }
                AudioSpectrum.from(tap).process(bufferList, frames: Int(framesOut.pointee))
            }
        )
        var tap: MTAudioProcessingTap?
        guard MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap) == noErr else{
            return nil
        }
        return tap
    }

    /// 从处理节点的storage取出当前对象
    private static func from(_ tap: MTAudioProcessingTap) -> AudioSpectrum {
        return Unmanaged<AudioSpectrum>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    }

    /// 处理节点准备好,记下音频格式,重新开始累积采样
    private func prepare(_ format: AudioStreamBasicDescription) {
        self.lock.lock()
        self.format = format
        self.sampleCount = 0
        self.lock.unlock()
    }

    /// 音频线程:取第一个声道的采样,攒够一次FFT的数量就计算频谱;只支持32位浮点(AVPlayer的处理格式)
    private func process(_ bufferList: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        guard self.isEnabled, frames > 0 else{
            return
        }
        let format = self.format
        guard format.mFormatID == kAudioFormatLinearPCM, format.mFormatFlags & kAudioFormatFlagIsFloat != 0, format.mBitsPerChannel == 32 else{
            return
        }
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        guard let buffer = buffers.first, let data = buffer.mData?.assumingMemoryBound(to: Float.self) else{
            return
        }

        //交错格式时每帧有多个声道,只取第一个声道
        let stride = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0 ? 1 : max(1, Int(buffer.mNumberChannels))
        for i in 0 ..< frames{
            self.samples[self.sampleCount] = data[i * stride]
            self.sampleCount += 1
            if self.sampleCount == AudioSpectrum.FFT_SIZE{
                self.sampleCount = 0
                self.computeBands(sampleRate: Float(format.mSampleRate))
            }
        }
    }

    /// 计算频谱:加窗、FFT、按对数频率分段取最大值、换算成0到1
    private func computeBands(sampleRate: Float) {
        let n = AudioSpectrum.FFT_SIZE

        //时域波形:每几个采样取平均,去掉太细的抖动
        let step = n / AudioSpectrum.WAVE_COUNT
        var wave = [Float](repeating: 0, count: AudioSpectrum.WAVE_COUNT)
        for i in 0 ..< AudioSpectrum.WAVE_COUNT{
            var sum: Float = 0
            for j in 0 ..< step{
                sum += self.samples[i * step + j]
            }
            wave[i] = sum / Float(step)
        }
        var windowed = [Float](repeating: 0, count: n)
        vDSP_vmul(self.samples, 1, self.window, 1, &windowed, 1, vDSP_Length(n))
        var real = [Float](repeating: 0, count: n / 2)
        var imag = [Float](repeating: 0, count: n / 2)
        var magnitudes = [Float](repeating: 0, count: n / 2)
        real.withUnsafeMutableBufferPointer{ realPtr in
            imag.withUnsafeMutableBufferPointer{ imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer{
                    $0.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n / 2){
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(n / 2))
                    }
                }
                vDSP_fft_zrip(self.fftSetup, &split, 1, AudioSpectrum.LOG2N, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
            }
        }
        let binWidth = sampleRate / Float(n)
        let count = AudioSpectrum.BAND_COUNT
        let ratio = AudioSpectrum.MAX_FREQ / AudioSpectrum.MIN_FREQ
        var result = [Float](repeating: 0, count: count)
        for b in 0 ..< count{
            let low = AudioSpectrum.MIN_FREQ * pow(ratio, Float(b) / Float(count))
            let high = AudioSpectrum.MIN_FREQ * pow(ratio, Float(b + 1) / Float(count))
            let from = min(n / 2 - 1, max(1, Int(low / binWidth)))
            let to = min(n / 2 - 1, max(from, Int(high / binWidth)))
            var peak: Float = 0
            for i in from ... to{
                peak = max(peak, magnitudes[i])
            }

            //幅度按FFT大小归一化之后换算成分贝,高音补偿一些
            let db = 20 * log10(max(peak / Float(n), 1e-9)) + AudioSpectrum.HIGH_BOOST_DB * Float(b) / Float(count - 1)
            result[b] = min(1, max(0, (db - AudioSpectrum.MIN_DB) / AudioSpectrum.DB_RANGE))
        }
        self.lock.lock()
        if self.enabled{
            self.bands = result
            self.wave = wave
        }
        self.lock.unlock()
    }
}
