//
//  MusicCorrectPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 歌曲纠错,信赖用户的纠错直接生效
struct MusicCorrectPage: View {

    private let musicId: Int64

    @State private var name: String

    @State private var artist: String

    @State private var album: String

    @Environment(\.dismiss) private var dismiss

    init(_ music: MusicModel) {
        self.musicId = music.id
        self._name = State(initialValue: music.name ?? "")
        self._artist = State(initialValue: music.artist ?? "")
        self._album = State(initialValue: music.album ?? "")
    }

    var body: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title: "纠错") {
                SettingGroup(footer: "审核通过之后生效"){
                    SettingTextField(title: "歌名", text: self.$name, placeholder: "请输入歌名")
                    SettingTextField(title: "歌手", text: self.$artist, placeholder: "请输入歌手")
                    SettingTextField(title: "专辑", text: self.$album, placeholder: "请输入专辑")
                }
                SettingGroup{
                    SettingButtonSingle("提交", action: self.onSubmitClick)
                }
            }
        }
    }

    /// 提交按钮点击事件
    private func onSubmitClick(){
        if self.name.trim().isEmpty{
            Toast.show("请输入歌名")
            return
        }
        MusicApi.correct(id: self.musicId, name: self.name.trim(), artist: self.artist.trim(), album: self.album.trim()).send{
            Toast.show("提交成功")
            if SettingShared.user?.isFriend == true{
                MusicShared.loadInBackground()
            }
            self.dismiss()
        }
    }
}
