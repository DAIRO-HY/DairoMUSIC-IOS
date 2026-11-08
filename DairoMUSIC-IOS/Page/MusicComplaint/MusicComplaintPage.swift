//
//  MusicComplaintPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 歌曲投诉,从服务器提供的理由里选择
struct MusicComplaintPage: View {

    private let musicId: Int64

    /// 投诉理由的选项
    @State private var samples = [String]()

    /// 选中的理由
    @State private var selected: String?

    @Environment(\.dismiss) private var dismiss

    init(musicId: Int64) {
        self.musicId = musicId
    }

    var body: some View {
        List{
            Section("请选择投诉理由"){
                ForEach(self.samples, id: \.self){ sample in
                    Button(action: {
                        self.selected = sample
                    }){
                        HStack{
                            Text(sample).foregroundColor(.primary)
                            Spacer()
                            if self.selected == sample{
                                Image(systemName: "checkmark").foregroundColor(.theme)
                            }
                        }
                    }
                }
            }
            Section{
                Button(action: self.onSubmitClick){
                    Text("提交").frame(maxWidth: .infinity)
                }
                .disabled(self.selected == nil)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("投诉")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear{
            if self.samples.isEmpty{
                MusicApi.complaintSamples().send{
                    self.samples = $0
                }
            }
        }
    }

    /// 提交按钮点击事件
    private func onSubmitClick(){
        guard let selected = self.selected else{
            return
        }
        MusicApi.complaint(id: self.musicId, content: selected).send{
            Toast.show("投诉已提交,感谢你的反馈")
            self.dismiss()
        }
    }
}
