//
//  DiscoverPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import DairoUI_IOS

struct DiscoverPage: View {

    /// 表格显示时歌单的最小宽度,iPhone上每行3个,iPad上根据屏幕宽度自动增加
    private static let GRID_ITEM_MIN_WIDTH: CGFloat = 100

    /// 轮播的最大宽度,避免iPad上轮播图太高
    private static let SWIPER_MAX_WIDTH: CGFloat = 800

    /// 轮播自动切换的间隔(秒)
    private static let SWIPER_INTERVAL = 6.0

    @StateObject private var vm = DiscoverViewModel()

    /// 轮播自动切换的计时器
    private let swiperTimer = Timer.publish(every: DiscoverPage.SWIPER_INTERVAL, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView{
            ScrollView{
                VStack(alignment: .leading, spacing: 16){
                    self.searchBar
                    if !self.vm.swiperList.isEmpty{
                        self.swiperView
                    }
                    ForEach(self.vm.usefulList, id: \.self){ group in
                        self.usefulGroupView(group)
                    }
                }
                .padding(.bottom)
            }
            .refreshable {
                self.vm.loadData()
            }
            .safeAreaInset(edge: .bottom, spacing: 0){
                HomeTabView(.DISCOVER_PAGE)
            }
            .navigationTitle("发现")
            .navigationBarHidden(true)
            .onReceive(self.swiperTimer){ _ in
                self.vm.nextSwiper()
            }
        }
        //iPad上默认是左右分栏,这里要全屏显示
        .navigationViewStyle(.stack)
    }

    /// 搜索按钮
    private var searchBar: some View {
        NavigationLink(destination: SearchPage()){
            HStack{
                Image(systemName: "magnifyingglass")
                Text("搜索歌曲、歌手")
                Spacer()
            }
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .frame(height: 40)
            .liquidGlassBackground(in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// 轮播
    private var swiperView: some View {
        GeometryReader{ geo in
            TabView(selection: self.$vm.swiperIndex){
                ForEach(self.vm.swiperList.indices, id: \.self){ i in
                    let item = self.vm.swiperList[i]
                    self.swiperItem(item)
                        .frame(width: geo.size.width - 32, height: geo.size.height)
                        .cornerRadius(12)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
        .aspectRatio(2.5, contentMode: .fit)
        .frame(maxWidth: DiscoverPage.SWIPER_MAX_WIDTH)
        .frame(maxWidth: .infinity)
    }

    /// 轮播的一项,推荐歌单跳转到歌单页面,其他类型交给ViewModel处理
    @ViewBuilder
    private func swiperItem(_ item: SwiperModel) -> some View {
        let image = MusicImage(item.image, placeholder: "photo")
        if item.type == 1, let id = item.data.flatMap({ Int64($0) }){
            NavigationLink(destination: MusicListPage(favoriteId: id, name: item.name)){
                image
            }
            .buttonStyle(.plain)
        } else {
            Button(action: {
                self.vm.onSwiperClick(item)
            }){
                image
            }
            .buttonStyle(.plain)
        }
    }

    /// 推荐歌单分组
    private func usefulGroupView(_ group: UsefulModel) -> some View {
        VStack(alignment: .leading, spacing: 10){
            if let name = group.name, !name.isEmpty{
                Text(name).font(.headline).padding(.horizontal)
            }
            if group.type == 2{//横向滚动
                ScrollView(.horizontal, showsIndicators: false){
                    LazyHStack(alignment: .top, spacing: 12){
                        ForEach(group.favorites, id: \.self){
                            self.favoriteCard($0).frame(width: 100)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {//表格显示
                LazyVGrid(columns: [GridItem(.adaptive(minimum: DiscoverPage.GRID_ITEM_MIN_WIDTH), spacing: 12)], spacing: 16){
                    ForEach(group.favorites, id: \.self){
                        self.favoriteCard($0)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// 推荐歌单
    private func favoriteCard(_ favorite: FavoriteModel) -> some View {
        NavigationLink(destination: MusicListPage(favoriteId: favorite.id, name: favorite.name)){
            VStack(alignment: .leading, spacing: 6){
                //先确定正方形的区域再放图片,图片直接设置比例时会按图片自己的比例撑开,不同尺寸的封面大小不一
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(MusicImage(favorite.logo, placeholder: "music.note.list"))
                    .clipped()
                    .cornerRadius(8)
                Text(favorite.name)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DiscoverPage()
}
