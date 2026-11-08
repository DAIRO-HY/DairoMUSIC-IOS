//
//  FavoriteEditViewModel.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

class FavoriteEditViewModel: ObservableObject {

    ///上传封面的最大边长
    private static let LOGO_MAX_SIZE: CGFloat = 800

    let favoriteId: Int64

    @Published var name = ""

    @Published var description = ""

    @Published var logo: String?

    init(favoriteId: Int64) {
        self.favoriteId = favoriteId
        if let favorite = FavoriteShared.byId(favoriteId){
            self.name = favorite.name
            self.description = favorite.description ?? ""
            self.logo = favorite.logo
        }
    }

    /// 保存点击事件
    func onSaveClick(){
        let name = self.name.trim()
        if name.isEmpty{
            Toast.show("请输入歌单名")
            return
        }
        FavoriteApi.edit(id: self.favoriteId, name: name, description: self.description.trim()).send{
            Toast.show("保存成功")
            FavoriteShared.loadInBackground()
        }
    }

    /// 选择封面之后上传
    func onLogoPick(_ image: UIImage){
        guard let jpeg = image.toJpeg(maxSize: FavoriteEditViewModel.LOGO_MAX_SIZE) else{
            Toast.show("读取图片失败")
            return
        }
        FavoriteApi.logo(id: self.favoriteId, jpeg: jpeg).send{
            self.logo = $0
            FavoriteShared.loadInBackground()
        }
    }
}
