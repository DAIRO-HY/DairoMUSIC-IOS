//
//  PlayingWaveSettingPage.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/19.
//

import SwiftUI
import DairoUI_IOS

/// 播放页波形的设置:选择波形样式,低音冲击波和波形颜色跟随封面的开关
struct PlayingWaveSettingPage: View {

    /// 波形样式
    @AppStorage(SettingStore.KEY_PLAYING_WAVE_STYLE) private var waveStyle = PlayingWaveStyle.bars.rawValue

    /// 是否显示低音冲击波
    @AppStorage(SettingStore.KEY_PLAYING_WAVE_SHOCKWAVE) private var waveShockwave = true

    /// 波形颜色是否跟随封面
    @AppStorage(SettingStore.KEY_PLAYING_WAVE_COVER_COLOR) private var waveCoverColor = true

    var body: some View {
        SettingStack(embedInNavigationStack: false) {
            SettingPage(title: "播放页波形") {
                SettingGroup{
                    for style in PlayingWaveStyle.allCases{
                        SettingCustomView{
                            self.styleRow(style)
                        }
                    }
                }

                //关闭波形时这两项没有作用,不显示
                if self.waveStyle != PlayingWaveStyle.off.rawValue{
                    SettingGroup(footer: "低音冲击波:鼓点时从封面边缘往外扩散一圈光环;跟随封面:波形的颜色从封面里取,每首歌都不一样"){
                        SettingToggle(title: "低音冲击波", isOn: self.$waveShockwave)
                        SettingToggle(title: "波形颜色跟随封面", isOn: self.$waveCoverColor)
                    }
                }
            }
        }
    }

    /// 一个样式选项,选中的打勾
    private func styleRow(_ style: PlayingWaveStyle) -> some View {
        Button(action: {
            self.waveStyle = style.rawValue
        }){
            HStack{
                Text(style.label)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if self.waveStyle == style.rawValue{
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.row)
        .accessibilityAddTraits(self.waveStyle == style.rawValue ? .isSelected : [])
    }
}

#Preview {
    PlayingWaveSettingPage()
}
