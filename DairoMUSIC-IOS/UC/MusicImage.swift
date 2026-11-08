//
//  MusicImage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI

/**
 通过SDK加载的图片,尺寸由调用方通过frame指定
 视图消失时连接断开,SDK会自动取消下载
 */
struct MusicImage: View {

    ///已解码图片的内存缓存,避免列表滑动时重新解码
    private static let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        cache.totalCostLimit = 100 * 1024 * 1024
        return cache
    }()

    /// 请求的都是SDK的本机服务,真正的下载并发由SDK控制
    /// URLSession.shared在iOS上同一个地址最多同时4个连接,列表里的图片会排队等待
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 64

        //SDK已经缓存了图片,这里不用再缓存
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    ///图片地址
    private let url: String?

    ///没有图片或者加载失败时显示的图标
    private let placeholder: String

    @State private var uiImage: UIImage?

    init(_ url: String?, placeholder: String = "music.note") {
        self.url = url
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack{
            if let uiImage = self.uiImage{
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ImagePlaceholder(self.placeholder)
            }
        }
        .clipped()
        .task(id: self.url){
            await self.load()
        }
    }

    /// 加载图片
    private func load() async {
        guard let url = self.url, !url.isEmpty else{
            self.uiImage = nil
            return
        }
        let key = url as NSString
        if let uiImage = MusicImage.memoryCache.object(forKey: key){
            self.uiImage = uiImage
            return
        }
        self.uiImage = nil
        guard let localUrl = FileSdkUtil.localUrl(FileSource.image(url)) else{
            return
        }
        guard let (data, response) = try? await MusicImage.session.data(from: localUrl) else{
            return
        }
        let uiImage = await Task.detached{
            return UIImage(data: data)?.preparingForDisplay()
        }.value
        if Task.isCancelled{
            return
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200, let uiImage else{
            return
        }
        let cost = Int(uiImage.size.width * uiImage.size.height * uiImage.scale * uiImage.scale * 4)
        MusicImage.memoryCache.setObject(uiImage, forKey: key, cost: cost)
        self.uiImage = uiImage
    }
}
