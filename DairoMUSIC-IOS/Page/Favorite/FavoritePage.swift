//
//  FavoritePage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

/// 我的歌单
struct FavoritePage: View {

    @StateObject private var vm = FavoriteViewModel()

    /// 显示新建歌单的输入框
    @State private var showCreateAlert = false

    /// 要删除的歌单
    @State private var deleteFavorite: FavoriteModel?

    /// 列表编辑模式,用来拖动排序
    @State private var editMode = EditMode.inactive

    /// 分组卡片的左右边距
    private static let CARD_MARGIN: CGFloat = 16

    /// iOS17开始用contentMargins缩小列表行的宽度,左滑删除的按钮在卡片里面;iOS16只能把卡片背景缩进,删除按钮在屏幕边上
    private static var useContentMargins: Bool {
        if #available(iOS 17, *){
            return true
        }
        return false
    }

    /// 卡片里歌单行的边距,歌单行自己还有上下4的边距
    private static let ROW_PADDING = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)

    var body: some View {
        NavigationView{

            //系统分组列表的圆角不能修改,这里用普通列表,每一行自己画圆角卡片背景,圆角和"我的"页面的分组一样
            List{
                Section{
                    if let like = self.vm.likeFavorite{
                        self.cardRow(isFirst: true, isLast: false){
                            NavigationLink(destination: MusicListPage(favoriteId: like.id, name: like.name)){
                                FavoriteItemView(like)
                            }
                        }
                    }
                    self.cardRow(isFirst: self.vm.likeFavorite == nil, isLast: true){
                        NavigationLink(destination: MusicListPage(favoriteId: FavoriteType.LATE, name: "最近播放")){
                            FavoriteItemView(name: "最近播放", icon: "clock.fill", iconColor: .theme, musicCount: self.vm.lateCount)
                        }
                    }
                }
                Section{
                    ForEach(Array(self.vm.userFavorites.enumerated()), id: \.element.id){ i, favorite in
                        self.cardRow(isFirst: i == 0, isLast: i == self.vm.userFavorites.count - 1){
                            NavigationLink(destination: MusicListPage(favoriteId: favorite.id, name: favorite.name)){
                                FavoriteItemView(favorite)
                            }
                        }
                        .swipeActions(edge: .trailing){
                            Button("删除", role: .destructive){
                                self.deleteFavorite = favorite
                            }
                        }
                    }
                    .onMove(perform: self.vm.onMove)
                } header: {
                    HStack{
                        Text("我的歌单").foregroundColor(.secondary)
                        Spacer()
                        if !self.vm.userFavorites.isEmpty{
                            Button(self.editMode.isEditing ? "完成" : "排序"){
                                withAnimation {
                                    self.editMode = self.editMode.isEditing ? .inactive : .active
                                }
                            }
                            .font(.subheadline)
                        }
                        Button(action: {
                            self.vm.createName = ""
                            self.showCreateAlert = true
                        }){
                            Image(systemName: "plus")
                        }
                        .padding(.leading, 8)
                        .accessibilityLabel("新建歌单")
                    }
                    .font(.subheadline)
                    .textCase(nil)

                    //和卡片里的封面对齐
                    .padding(.horizontal, FavoritePage.ROW_PADDING.leading)
                } footer: {
                    if self.vm.userFavorites.isEmpty{
                        Text("点击右上角的+新建歌单")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, FavoritePage.ROW_PADDING.leading)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .modifier(CardMarginModifier(margin: FavoritePage.useContentMargins ? FavoritePage.CARD_MARGIN : 0))
            .environment(\.editMode, self.$editMode)
            .refreshable {
                FavoriteShared.loadInBackground()
                MusicShared.loadInBackground()
            }
            .safeAreaInset(edge: .bottom, spacing: 0){
                HomeTabView(.FAVORITE_PAGE)
            }
            .navigationTitle("音乐")
            .navigationBarHidden(true)
            .alert("新建歌单", isPresented: self.$showCreateAlert){
                TextField("请输入歌单名", text: self.$vm.createName)
                Button("创建", action: self.vm.onCreateClick)
                Button("取消", role: .cancel){}
            }
            .alert("确定删除歌单「\(self.deleteFavorite?.name ?? "")」吗？", isPresented: Binding(get: { self.deleteFavorite != nil }, set: { if !$0 { self.deleteFavorite = nil } })){
                Button("删除", role: .destructive){
                    if let favorite = self.deleteFavorite{
                        self.vm.onDeleteClick(favorite)
                    }
                }
                Button("取消", role: .cancel){}
            }
        }
        //iPad上默认是左右分栏,这里要全屏显示
        .navigationViewStyle(.stack)
    }

    /// 卡片里的一行,第一行画上面的圆角,最后一行画下面的圆角,中间的行下面画分隔线
    private func cardRow<Content: View>(isFirst: Bool, isLast: Bool, @ViewBuilder content: () -> Content) -> some View {
        let padding = FavoritePage.ROW_PADDING
        let margin = FavoritePage.useContentMargins ? 0 : FavoritePage.CARD_MARGIN
        return content()
            .listRowInsets(EdgeInsets(top: padding.top, leading: margin + padding.leading, bottom: padding.bottom, trailing: margin + padding.trailing))
            .listRowSeparator(.hidden)
            .listRowBackground(FavoriteCardBackground(isFirst: isFirst, isLast: isLast, separatorLeading: padding.leading + FavoriteItemView.TEXT_LEADING)
                .padding(.horizontal, margin))
    }
}

/// 列表左右的边距,iOS17以上才有contentMargins
private struct CardMarginModifier: ViewModifier {

    let margin: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 17, *){
            content.contentMargins(.horizontal, self.margin, for: .scrollContent)
        } else {
            content
        }
    }
}

/// 歌单卡片一行的背景,圆角和"我的"页面的分组(SettingGroup)一样
private struct FavoriteCardBackground: View {

    /// 圆角半径,和SettingGroup默认的一样
    private static let CORNER_RADIUS: CGFloat = 12

    /// 是否第一行,画上面的圆角
    let isFirst: Bool

    /// 是否最后一行,画下面的圆角,不画分隔线
    let isLast: Bool

    /// 分隔线左边的缩进,和歌单名对齐
    let separatorLeading: CGFloat

    var body: some View {
        var corners = UIRectCorner()
        if self.isFirst{
            corners.formUnion([.topLeft, .topRight])
        }
        if self.isLast{
            corners.formUnion([.bottomLeft, .bottomRight])
        }
        return RoundedCornerShape(radius: FavoriteCardBackground.CORNER_RADIUS, corners: corners)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(alignment: .bottom){
                if !self.isLast{
                    Rectangle()
                        .fill(Color(uiColor: .separator))
                        .frame(height: 0.5)
                        .padding(.leading, self.separatorLeading)
                }
            }
    }
}

/// 指定哪几个角是圆角的矩形
private struct RoundedCornerShape: Shape {

    let radius: CGFloat

    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        return Path(UIBezierPath(roundedRect: rect, byRoundingCorners: self.corners, cornerRadii: CGSize(width: self.radius, height: self.radius)).cgPath)
    }
}

#Preview {
    FavoritePage()
}
