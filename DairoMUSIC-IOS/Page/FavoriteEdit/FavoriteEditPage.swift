//
//  FavoriteEditPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

struct FavoriteEditPage: View {

    @StateObject private var vm: FavoriteEditViewModel

    /// 显示图片选择器
    @State private var showImagePicker = false

    init(favoriteId: Int64) {
        self._vm = StateObject(wrappedValue: FavoriteEditViewModel(favoriteId: favoriteId))
    }

    var body: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title: "编辑歌单") {
                SettingCustomView{
                    Button(action: {
                        self.showImagePicker = true
                    }){
                        VStack(spacing: 8){
                            MusicImage(self.vm.logo, placeholder: "music.note.list")
                                .frame(width: 100, height: 100)
                                .cornerRadius(10)
                            Text("更换封面").font(.footnote).foregroundColor(.secondary)
                        }
                        .padding(24)
                    }
                    .frame(maxWidth: .infinity)
                }
                SettingGroup{
                    SettingTextField(title: "歌单名", text: self.$vm.name, placeholder: "请输入歌单名")
                    SettingTextField(title: "描述", text: self.$vm.description, placeholder: "可以不填")
                }
                SettingGroup{
                    SettingButtonSingle("保存", action: self.vm.onSaveClick)
                }
            }
        }
        .sheet(isPresented: self.$showImagePicker) {
            SingleImagePicker(isPresented: self.$showImagePicker, onPick: self.vm.onLogoPick)
        }
    }
}
