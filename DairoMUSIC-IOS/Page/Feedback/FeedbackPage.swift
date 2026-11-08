//
//  FeedbackPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 意见反馈
struct FeedbackPage: View {

    @State private var content = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List{
            Section{
                TextEditor(text: self.$content)
                    .frame(minHeight: 180)
            } header: {
                Text("请描述你遇到的问题或建议")
            }
            Section{
                Button(action: self.onSubmitClick){
                    Text("提交").frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("意见反馈")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 提交按钮点击事件
    private func onSubmitClick(){
        let content = self.content.trim()
        if content.isEmpty{
            Toast.show("请输入反馈内容")
            return
        }
        CommonApi.feedback(content: content).send{ msg in
            Toast.show(msg.isEmpty ? "感谢你的反馈" : msg)
            self.dismiss()
        }
    }
}
