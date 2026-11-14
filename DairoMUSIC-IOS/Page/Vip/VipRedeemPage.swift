//
//  VipRedeemPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/14.
//

import SwiftUI
import DairoUI_IOS

/// VIP状态和兑换VIP
struct VipRedeemPage: View {

    @StateObject private var vm = VipRedeemViewModel()

    /// VIP状态
    @ObservedObject private var config = ServerConfig.shared

    var body: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title: "VIP会员") {
                SettingGroup(footer: "VIP可以听超高品质、无损音质的歌曲,看原画视频,下载歌曲和视频"){
                    SettingText(title: "VIP状态：" + self.statusText)
                }
                SettingGroup(header: "兑换VIP", footer: "卡号是16位数字,卡密不区分大小写"){
                    SettingCustomView{
                        self.inputRow("卡号"){
                            TextField("16位数字", text: self.$vm.cardNo)
                                .keyboardType(.numberPad)
                        }
                    }
                    SettingCustomView{
                        self.inputRow("卡密"){
                            TextField("请输入卡密", text: self.$vm.cardPwd)
                                .keyboardType(.asciiCapable)
                                .textInputAutocapitalization(.characters)
                        }
                    }
                }
                SettingGroup{
                    SettingButtonSingle("兑换", action: self.vm.onRedeemClick)
                }
            }
        }
        .alert("确认兑换", isPresented: Binding(get: { self.vm.confirmMessage != nil }, set: { if !$0 { self.vm.confirmMessage = nil } })){
            Button("兑换"){
                self.vm.onConfirmClick()
            }
            Button("取消", role: .cancel){}
        } message: {
            Text(self.vm.confirmMessage ?? "")
        }
    }

    /// VIP状态的说明
    private var statusText: String {
        guard let vip = self.config.vip else{
            return "未开通"
        }
        if vip.forever{
            return "永久VIP"
        }
        if vip.isVip{
            return "有效期到" + vip.expireDateText
        }
        return vip.expireTime == 0 ? "未开通" : "已于" + vip.expireDateText + "到期"
    }

    /// 输入框的一行,和SettingTextField的样式一样
    private func inputRow<Field: View>(_ title: String, @ViewBuilder field: () -> Field) -> some View {
        HStack(spacing: 12){
            Text(title)
            field()
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .padding(.horizontal)
    }
}

#Preview {
    NavigationView{
        VipRedeemPage()
    }
}
