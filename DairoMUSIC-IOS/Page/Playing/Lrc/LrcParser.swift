//
//  LrcParser.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import Foundation

/// 一行歌词
struct LrcLine: Hashable {

    /// 开始时间(秒)
    let time: Double

    /// 歌词
    let text: String
}

/// 歌词解析,支持LRC格式和采集平台的WEBVTT字幕格式
enum LrcParser {

    /// 解析歌词,按时间排序
    static func parse(_ lrc: String) -> [LrcLine] {
        let lines = lrc.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        if lines.contains(where: { $0.contains("-->") }){
            return LrcParser.parseVtt(lines)
        }
        return LrcParser.parseLrc(lines)
    }

    /// LRC格式,一行可能有多个时间标签,例如:[00:12.34][01:20.00]歌词
    private static func parseLrc(_ lines: [String]) -> [LrcLine] {
        var result = [LrcLine]()
        for line in lines{
            var rest = Substring(line)
            var times = [Double]()
            while rest.hasPrefix("["), let end = rest.firstIndex(of: "]"){
                let tag = rest[rest.index(after: rest.startIndex) ..< end]
                guard let time = LrcParser.toSeconds(String(tag)) else{

                    //[ti:歌名]这类信息标签,不显示
                    break
                }
                times.append(time)
                rest = rest[rest.index(after: end)...]
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            for time in times{
                result.append(LrcLine(time: time, text: text))
            }
        }
        return result.sorted{ $0.time < $1.time }
    }

    /// WEBVTT格式,时间行之后到空行之前都是这一段的字幕
    /// 00:00:01.000 --> 00:00:04.000
    private static func parseVtt(_ lines: [String]) -> [LrcLine] {
        var result = [LrcLine]()
        var time: Double?
        var texts = [String]()
        let flush = {
            if let time{
                result.append(LrcLine(time: time, text: texts.joined(separator: "\n")))
            }
            time = nil
            texts = []
        }
        for line in lines{
            if line.contains("-->"){
                flush()
                let start = line.components(separatedBy: "-->")[0].trimmingCharacters(in: .whitespaces)
                time = LrcParser.toSeconds(start)
                continue
            }
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.isEmpty{
                flush()
                continue
            }
            if time != nil{
                texts.append(text)
            }
        }
        flush()
        return result.sorted{ $0.time < $1.time }
    }

    /// 时间转换成秒,支持 mm:ss.xx 和 hh:mm:ss.xxx
    private static func toSeconds(_ value: String) -> Double? {
        let parts = value.replacingOccurrences(of: ",", with: ".").components(separatedBy: ":")
        guard parts.count >= 2 && parts.count <= 3 else{
            return nil
        }
        var seconds = 0.0
        for part in parts{
            guard let number = Double(part) else{
                return nil
            }
            seconds = seconds * 60 + number
        }
        return seconds
    }
}
