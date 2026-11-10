//
//  AboutPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 关于,版本信息、免责声明、隐私政策
struct AboutPage: View {

    /// 免责声明
    private static let DISCLAIMER = "DAIRO音乐是一个音乐播放客户端，本身不提供任何音乐、视频内容。App里播放和下载的内容全部来自你自己填写的服务器，由服务器的管理者负责。请只播放和下载你有权使用的内容，尊重音乐版权，不要用于商业用途。"

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
                //App Store审核不允许引导到App Store以外的地方更新,上架版本暂时不显示检查更新
                //SettingGroup{
                //    SettingButton("检查更新", action: self.onCheckClick)
                //}
                SettingGroup{
                    SettingNavigationLink("隐私政策"){
                        PrivacyPage().anyView
                    }
                }
                SettingGroup(header: "免责声明"){
                    SettingCustomView{
                        Text(AboutPage.DISCLAIMER)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
        //固定显示在屏幕最底部
        .overlay(alignment: .bottom){
            ServerGithubLink("服务器端项目地址")
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
