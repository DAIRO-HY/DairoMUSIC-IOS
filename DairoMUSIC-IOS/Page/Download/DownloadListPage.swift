//
//  DownloadListPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/08.
//

import SwiftUI
import DairoFileSDK
import DairoUI_IOS

/// 已下载的歌曲、视频列表,显示下载进度,可以暂停、继续、删除,支持多选删除
struct DownloadListPage: View {

    @StateObject private var vm: DownloadListViewModel

    /// 显示全部删除的确认框
    @State private var showDeleteAllAlert = false

    /// 显示删除选中的确认框
    @State private var showDeleteSelectedAlert = false

    /// 多选模式
    @State private var editMode = EditMode.inactive

    /// 选中的下载ID
    @State private var selection = Set<String>()

    init(_ type: DownloadType) {
        self._vm = StateObject(wrappedValue: DownloadListViewModel(type))
    }

    var body: some View {
        List(selection: self.$selection){
            ForEach(self.vm.items, id: \.id){ info in
                DownloadItemView(info: info, isEditing: self.editMode.isEditing){
                    self.vm.onStateClick(info)
                }
                .swipeActions(edge: .trailing){
                    Button("删除", role: .destructive){
                        self.vm.delete([info.id])
                    }
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, self.$editMode)
        .overlay{
            if self.vm.items.isEmpty{
                Text(self.vm.type.emptyText).foregroundColor(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0){
            if self.editMode.isEditing{
                self.deleteBar
            }
        }
        .navigationTitle(self.vm.type.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(self.editMode.isEditing)
        .toolbar{
            if self.editMode.isEditing{
                ToolbarItem(placement: .navigationBarLeading){
                    Button(self.isAllSelected ? "取消全选" : "全选"){
                        self.selection = self.isAllSelected ? [] : Set(self.vm.items.map{ $0.id })
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing){
                    Button("完成"){
                        self.setEditing(false)
                    }
                }
            } else if !self.vm.items.isEmpty{
                ToolbarItem(placement: .navigationBarTrailing){
                    Button("选择"){
                        self.setEditing(true)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing){
                    Button(action: {
                        self.showDeleteAllAlert = true
                    }){
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("全部删除")
                }
            }
        }
        .alert(self.vm.type.deleteAllTitle, isPresented: self.$showDeleteAllAlert){
            Button("删除", role: .destructive, action: self.vm.deleteAll)
            Button("取消", role: .cancel){}
        }
        .alert("确定删除选中的\(self.selection.count)个吗？", isPresented: self.$showDeleteSelectedAlert){
            Button("删除", role: .destructive){
                self.vm.delete(Array(self.selection))
                self.setEditing(false)
            }
            Button("取消", role: .cancel){}
        }
        .onChange(of: self.vm.items){ items in

            //删除或者下载记录被清理之后,去掉已经不存在的选中项
            let ids = Set(items.map{ $0.id })
            if !self.selection.isSubset(of: ids){
                self.selection.formIntersection(ids)
            }
            if items.isEmpty && self.editMode.isEditing{
                self.setEditing(false)
            }
        }
        .onAppear(perform: self.vm.start)
        .onDisappear(perform: self.vm.stop)
    }

    /// 多选模式下底部的删除按钮
    private var deleteBar: some View {
        Button(action: {
            self.showDeleteSelectedAlert = true
        }){
            Text(self.selection.isEmpty ? "删除" : "删除(\(self.selection.count))")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Capsule().fill(self.selection.isEmpty ? Color.gray.opacity(0.5) : Color.red))
        }
        .buttonStyle(.plain)
        .disabled(self.selection.isEmpty)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// 是否已经全部选中
    private var isAllSelected: Bool {
        return !self.vm.items.isEmpty && self.selection.count == self.vm.items.count
    }

    /// 进入或退出多选模式,退出时清空选择
    private func setEditing(_ isEditing: Bool) {
        withAnimation{
            self.editMode = isEditing ? .active : .inactive
        }
        if !isEditing{
            self.selection = []
        }
    }
}

/// 下载列表的一行:封面、名称、进度,右边是暂停、继续、重试按钮
private struct DownloadItemView: View {

    let info: CacheInfo

    /// 多选模式下不显示暂停、继续按钮,点一行是选中
    let isEditing: Bool

    /// 暂停、继续、重试按钮点击事件
    let onStateClick: () -> Void

    var body: some View {
        let name = DownloadName(self.info.name ?? "")
        HStack(spacing: 12){
            MusicImage(self.info.thumb)
                .frame(width: 48, height: 48)
                .cornerRadius(6)
            VStack(alignment: .leading, spacing: 4){
                Text(name.title).lineLimit(1)
                Text(self.subtitle(name)).font(.footnote).foregroundColor(self.info.state == .error ? .red : .secondary).lineLimit(1)
                if self.info.state != .finish{
                    ProgressView(value: self.progress).tint(.theme)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !self.isEditing, let icon = self.stateIcon{
                Button(action: self.onStateClick){
                    Image(systemName: icon.name)
                        .font(.title2)
                        .foregroundColor(.theme)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.label)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// 下载进度(0到1)
    private var progress: Double {
        guard let size = self.info.size, size > 0 else{
            return 0
        }
        return min(Double(self.info.downloaded) / Double(size), 1)
    }

    /// 歌手、音质和下载状态
    private func subtitle(_ name: DownloadName) -> String {
        let detail = [name.artist, name.quality].filter{ !$0.isEmpty }.joined(separator: " · ")
        let sizeText = self.info.size.map{ Int64($0).fileSize }
        switch self.info.state{
        case .finish:
            return [detail, sizeText ?? ""].filter{ !$0.isEmpty }.joined(separator: " · ")
        case .downloading:
            let downloaded = Int64(self.info.downloaded).fileSize
            return "下载中 \(Int(self.progress * 100))% · " + (sizeText.map{ downloaded + "/" + $0 } ?? downloaded)
        case .waiting:
            return "等待下载"
        case .paused:
            return "已暂停 \(Int(self.progress * 100))%"
        case .error:
            return "下载失败" + (self.info.error.map{ ":" + $0 } ?? "")
        }
    }

    /// 右边的按钮,下载完成时没有
    private var stateIcon: (name: String, label: String)? {
        switch self.info.state{
        case .downloading, .waiting:
            return ("pause.circle", "暂停下载")
        case .paused:
            return ("arrow.down.circle", "继续下载")
        case .error:
            return ("arrow.clockwise.circle", "重新下载")
        case .finish:
            return nil
        }
    }
}

/// 下载文件名"歌名 - 歌手 [音质].扩展名"拆分之后的各部分
private struct DownloadName {

    /// 歌名
    let title: String

    /// 歌手
    let artist: String

    /// 音质、清晰度
    let quality: String

    init(_ fileName: String) {
        var base = (fileName as NSString).deletingPathExtension
        var quality = ""
        if base.hasSuffix("]"), let start = base.range(of: " [", options: .backwards){
            quality = String(base[start.upperBound ..< base.index(before: base.endIndex)])
            base = String(base[..<start.lowerBound])
        }
        if let separator = base.range(of: " - "){
            self.title = String(base[..<separator.lowerBound])
            self.artist = String(base[separator.upperBound...])
        } else {
            self.title = base
            self.artist = ""
        }
        self.quality = quality
    }
}
