//
//  CachePage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 缓存管理,播放过的歌曲和看过的图片都缓存在SDK里
struct CachePage: View {

    @StateObject private var vm = CacheViewModel()

    /// 要清理的缓存分组,空字符串表示全部
    @State private var clearGroup: String?

    /// 音乐边播边缓存
    @AppStorage(SettingShared.KEY_MUSIC_CACHE) private var musicCache = true

    /// 视频边播边缓存
    @AppStorage(SettingShared.KEY_VIDEO_CACHE) private var videoCache = false

    var body: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title: "缓存管理") {
                SettingGroup(footer: "关闭之后没有缓存的歌曲、视频直接在线播放,已经缓存好的仍然播放本地文件"){
                    SettingToggle(title: "音乐边播边缓存", isOn: self.$musicCache)
                    SettingToggle(title: "视频边播边缓存", isOn: self.$videoCache)
                }
                SettingGroup(footer: "下载的歌曲和视频永久保存,清理缓存时不会删除"){
                    SettingNavigationLink("已下载的歌曲", tip: self.vm.downloadMusicText){
                        DownloadListPage(.music).anyView
                    }
                    .icon("arrow.down.circle.fill", backgroundColor: Color.green)
                    SettingNavigationLink("已下载的视频", tip: self.vm.downloadVideoText){
                        DownloadListPage(.video).anyView
                    }
                    .icon("arrow.down.circle.fill", backgroundColor: Color.orange)
                }
                SettingGroup(footer: "正在播放的歌曲不会被清理"){
                    SettingButton("歌曲缓存", tip: self.vm.musicSize){
                        self.clearGroup = FileSdkUtil.GROUP_MUSIC
                    }
                    .icon("music.note", backgroundColor: Color.theme)
                    SettingButton("视频缓存", tip: self.vm.videoSize){
                        self.clearGroup = FileSdkUtil.GROUP_VIDEO
                    }
                    .icon("film.fill", backgroundColor: Color.orange)
                    SettingButton("图片缓存", tip: self.vm.imageSize){
                        self.clearGroup = FileSdkUtil.GROUP_IMAGE
                    }
                    .icon("photo.fill", backgroundColor: Color.blue)
                }
                SettingGroup(footer: "超过上限时自动清理最久没有播放的歌曲"){
                    SettingPicker("缓存上限", data: CacheViewModel.MAX_SIZE_DATA, value: self.$vm.maxSize, changeFunc: self.vm.onMaxSizeChange)
                        .icon("internaldrive.fill", backgroundColor: Color.indigo)
                }
                SettingGroup{
                    SettingButtonSingle("清理全部缓存"){
                        self.clearGroup = ""
                    }
                }
            }
        }
        .onAppear(perform: self.vm.loadSize)
        .alert(self.clearTitle, isPresented: Binding(get: { self.clearGroup != nil }, set: { if !$0 { self.clearGroup = nil } })){
            Button("清理", role: .destructive){
                if let group = self.clearGroup{
                    self.vm.onClearClick(group.isEmpty ? nil : group)
                }
            }
            Button("取消", role: .cancel){}
        }
    }

    /// 清理确认框的标题
    private var clearTitle: String {
        switch self.clearGroup{
        case FileSdkUtil.GROUP_MUSIC:
            return "确定清理歌曲缓存吗？"
        case FileSdkUtil.GROUP_IMAGE:
            return "确定清理图片缓存吗？"
        case FileSdkUtil.GROUP_VIDEO:
            return "确定清理视频缓存吗？"
        default:
            return "确定清理全部缓存吗？"
        }
    }
}

class CacheViewModel: ObservableObject {

    /// 缓存上限的选项(MB),0表示不限制
    static let MAX_SIZE_DATA = [
        SettingPickerData("1GB", 1024),
        SettingPickerData("2GB", 2 * 1024),
        SettingPickerData("5GB", 5 * 1024),
        SettingPickerData("10GB", 10 * 1024),
        SettingPickerData("不限制", 0)
    ]

    /// 歌曲缓存大小
    @Published var musicSize = "计算中"

    /// 图片缓存大小
    @Published var imageSize = "计算中"

    /// 视频缓存大小,不包括已经下载的视频
    @Published var videoSize = "计算中"

    /// 已下载的歌曲数量和大小
    @Published var downloadMusicText = "计算中"

    /// 已下载的视频数量和大小
    @Published var downloadVideoText = "计算中"

    /// 缓存上限(MB)
    @Published var maxSize = SettingShared.fileSdkMaxCacheSize

    /// 统计缓存和下载的大小,页面显示时刷新,从下载列表删除之后回来会更新
    func loadSize(){
        DispatchQueue.global().async {
            let stats = FileSdkUtil.stats(mode: .cache)
            let sizeOf = { (group: String) -> String in
                let size = stats.first{ $0.group == group }?.size ?? 0
                return Int64(size).fileSize
            }
            let musicSize = sizeOf(FileSdkUtil.GROUP_MUSIC)
            let imageSize = sizeOf(FileSdkUtil.GROUP_IMAGE)
            let videoSize = sizeOf(FileSdkUtil.GROUP_VIDEO)

            //下载按当前服务器统计,包括还没有下载完成的
            let downloadText = { (group: String, unit: String) -> String in
                let list = FileSdkUtil.downloads(group: group)
                if list.isEmpty{
                    return "无"
                }
                let size = list.reduce(UInt64(0)){ $0 + ($1.state == .finish ? ($1.size ?? $1.downloaded) : $1.downloaded) }
                return "\(list.count)\(unit) · " + Int64(size).fileSize
            }
            let downloadMusicText = downloadText(FileSdkUtil.GROUP_MUSIC, "首")
            let downloadVideoText = downloadText(FileSdkUtil.GROUP_VIDEO, "个")
            DispatchQueue.main.async {
                self.musicSize = musicSize
                self.imageSize = imageSize
                self.videoSize = videoSize
                self.downloadMusicText = downloadMusicText
                self.downloadVideoText = downloadVideoText
            }
        }
    }

    /// 清理缓存,SDK清理时会读写文件,不能在主线程调用
    /// - Parameter group: 缓存分组,为nil时清理全部
    func onClearClick(_ group: String?){
        Loading.show()
        DispatchQueue.global().async {
            FileSdkUtil.clearCache(group: group)
            DispatchQueue.main.async {
                Loading.hide()
                Toast.show("清理完成")
                self.loadSize()
            }
        }
    }

    /// 修改缓存上限
    func onMaxSizeChange(_ value: Int) -> Bool{
        SettingShared.fileSdkMaxCacheSize = value
        FileSdkUtil.setMaxCacheSize(value)
        return true
    }
}
