//
//  MusicInfoViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
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

    /// 可以收藏到的歌单
    var favoriteList: [FavoriteModel] {
        return FavoriteShared.list
    }

    init(_ music: MusicModel, favoriteId: Int64?) {
        self.music = music
        self.favorite = favoriteId.flatMap{ FavoriteShared.byId($0) }
        self.updateLike()
        self.downloadedText = MusicDownloadUtil.downloadedText(music.id)
    }

    /// 下载选择的音质
    func onDownloadClick(_ quality: DownloadQuality){
        MusicDownloadUtil.download(self.music, quality: quality)
        self.downloadedText = self.downloadedText ?? "下载中"
    }

    /// 更新"我喜欢"状态
    func updateLike(){
        self.isLike = self.music.id != 0 && MusicShared.isLike(self.music.id)
    }

    /// 喜欢点击事件
    func onLikeClick(){
        MusicShared.toggleLike(self.music)
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
