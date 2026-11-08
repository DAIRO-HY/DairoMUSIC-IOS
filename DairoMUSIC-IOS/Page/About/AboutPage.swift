//
//  AboutPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 关于,版本信息、检查更新、免责声明
struct AboutPage: View {

    /// 检查到的新版本
    @State private var newVersion: AppVersionModel?

    var body: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title: "关于") {
                SettingCustomView{
                    VStack(spacing: 8){
                        Image("logo")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .cornerRadius(14)
                        Text("DAIRO音乐 \(Const.versionName)").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                }
                SettingGroup{
                    SettingButton("检查更新", action: self.onCheckClick)
                }
                SettingGroup(header: "免责声明"){
                    SettingCustomView{
                        Text("DAIRO音乐是一个音乐播放客户端，播放的内容来自你连接的服务器。音乐版权归各权利人所有，请支持正版，不要用于商业用途。")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
        .alert("发现新版本 \(self.newVersion?.versionName ?? "")", isPresented: Binding(get: { self.newVersion != nil }, set: { if !$0 { self.newVersion = nil } })){
            Button("去更新"){
                if let url = self.newVersion.flatMap({ URL(string: $0.url) }){
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel){}
        } message: {
            Text(self.newVersion?.instruction ?? "")
        }
    }

    /// 检查更新点击事件
    private func onCheckClick(){
        CommonApi.checkVersion().send{ version in
            guard let version else{
                Toast.show("已经是最新版本")
                return
            }
            self.newVersion = version
        }
    }
}
