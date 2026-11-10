//
//  MusicInfoViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoFileSDK
import DairoUI_IOS

class MusicInfoViewModel: ObservableObject {

    /// 歌曲信息
    @Published var music: MusicModel

    /// 歌曲所在的我的歌单,可以从这个歌单删除
    let favorite: FavoriteModel?

    /// 是否"我喜欢"的歌曲
    @Published var isLike = false

    /// 下载状态:已下载、下载中,没有下载时为nil
    @Published var downloadedText: String?

    /// 这首歌的所有下载,包括还没有下载完成的,删除下载时选择
    @Published var downloads = [CacheInfo]()

    /// 当前音质和文件大小,和播放时选择文件的规则一样
    @Published var displayFile: MusicFileModel?

    /// 显示的文件的说明:已下载、已缓存,在线播放时为nil
    @Published var displayTag: String?

    /// 可以收藏到的歌单
    var favoriteList: [FavoriteModel] {
        return FavoriteShared.list
    }

    init(_ music: MusicModel, favoriteId: Int64?) {
        self.music = music
        self.favorite = favoriteId.flatMap{ FavoriteShared.byId($0) }
        self.updateLike()
        self.updateDownload()
    }

    /// 更新下载状态和显示的文件
    func updateDownload(){
        self.downloads = MusicDownloadUtil.downloads(self.music.id)
        self.downloadedText = MusicDownloadUtil.downloadedText(self.music.id)
        let display = MusicFileResolver.displayFile(self.music)
        self.displayFile = display.file
        self.displayTag = display.tag
    }

    /// 下载选择的音质
    func onDownloadClick(_ quality: DownloadQuality){
        MusicDownloadUtil.download(self.music, quality: quality)
        self.downloadedText = self.downloadedText ?? "下载中"

        //添加下载任务之后刷新,可以删除正在下载的
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
            self.updateDownload()
        }
    }

    /// 删除下载的文件,正在播放的歌曲会继续播放完,下次播放时按新的规则选择文件
    /// - Parameter infos: 要删除的下载
    func onDeleteDownloadClick(_ infos: [CacheInfo]){
        MusicDownloadUtil.delete(infos.map{ $0.id })
        Toast.show("已删除下载")
        self.updateDownload()
    }

    /// 删除下载时显示的名称:音质、大小,没有下载完成的加上"下载中"
    func downloadLabel(_ info: CacheInfo) -> String {
        let file = FileSdkUtil.musicFileId(info.key).flatMap{ self.music.file(id: $0) }
        let size = (info.size.map{ Int64($0) } ?? file?.size)?.fileSize ?? ""
        let state = info.state == .finish ? "" : "(下载中)"
        return MusicModel.qualityText(file?.bitRate) + "  " + size + state
    }

    /// 更新"我喜欢"状态
    func updateLike(){
        self.isLike = self.music.id != 0 && MusicShared.isLike(self.music.id)
    }

    /// 喜欢点击事件
    func onLikeClick(){

        //采集平台的歌曲加入曲库之后更新歌曲ID,否则按ID判断"我喜欢"状态时一直是没有喜欢
        MusicShared.toggleLike(self.music){ musicId in
            self.music.id = musicId
            self.updateLike()
            self.updateDownload()
        }
    }

    /// 收藏到歌单
    func onAddToFavoriteClick(_ favorite: FavoriteModel){
        FavoriteShared.addMusic(self.music, favoriteId: favorite.id){ musicId in
            self.music.id = musicId
            Toast.show("已收藏到「\(favorite.name)」")
        }
    }

    /// 从歌单删除
    func onRemoveClick(success: @escaping () -> Void){
        guard let favorite = self.favorite else{
            return
        }
        FavoriteShared.removeMusic(musicId: self.music.id, favoriteId: favorite.id){
            Toast.show("已删除")
            success()
        }
    }

    /// 分享,分享链接是服务器上的网页,可以在线播放和下载
    func onShareClick(){
        MusicShared.ensureId(self.music){ musicId in
            self.music.id = musicId
            guard let url = URL(string: SettingShared.domainNotNull + ApiConst.SHARE_MUSIC + "?id=\(musicId)") else{
                return
            }
            let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  var top = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else{
                return
            }
            while let presented = top.presentedViewController{
                top = presented
            }

            //iPad上以气泡形式显示在页面中间
            vc.popoverPresentationController?.sourceView = top.view
            vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            vc.popoverPresentationController?.permittedArrowDirections = []
            top.present(vc, animated: true)
        }
    }
}
