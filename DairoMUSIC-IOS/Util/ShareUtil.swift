//
//  ShareUtil.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/15.
//

import UIKit
import DairoUI_IOS

/// 系统分享面板:分享链接,通过隔空投送、其他App发送下载的文件
enum ShareUtil {

    /// 发送下载的文件
    /// 缓存里的文件名不是歌名,先复制到临时目录,改成"歌名 - 歌手.扩展名"再发送,只保留这次要发送的文件
    /// - Parameter path: 下载的文件路径
    /// - Parameter name: 发送的文件名,不带扩展名
    /// - Parameter ext: 扩展名,为空时用下载文件的扩展名
    static func sendFile(_ path: String, name: String, ext: String?) {
        let source = URL(fileURLWithPath: path)
        let ext = ext.flatMap{ $0.isEmpty ? nil : $0 } ?? source.pathExtension
        let fileName = name.replacingOccurrences(of: "/", with: "_")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("send_file")
        let target = folder.appendingPathComponent(ext.isEmpty ? fileName : fileName + "." + ext)
        do{
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: source, to: target)
        } catch {
            Toast.show("读取文件失败")
            return
        }
        ShareUtil.present([target])
    }

    /// 弹出系统的分享面板,iPad上以气泡形式显示在页面中间
    static func present(_ items: [Any]) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var top = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else{
            return
        }
        while let presented = top.presentedViewController{
            top = presented
        }
        vc.popoverPresentationController?.sourceView = top.view
        vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
        vc.popoverPresentationController?.permittedArrowDirections = []
        top.present(vc, animated: true)
    }
}
