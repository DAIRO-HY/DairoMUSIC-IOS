# gl-music-ios

麦茤音乐IOS端
-
# 开启http(非https)支持的支持
## https://developer.apple.com/jp/news/?id=jxky8h89


# 安装pod失败解决方案
## https://qiita.com/spring_i/items/181bc3c05142d1f80d93
CocoaPodsのインストールで手間取ったこと
sell
CocoaPods
Flutterの環境構築で少し詰まったのでメモ。

詰まったこと
flutter doctorでエラーを消していく作業中、CocoaPodsのインストールで手間取った。

$ sudo gem install cocoapods
~~~省略~~~
Building native extensions. This could take a while...
ERROR:  Error installing cocoapods:
    ERROR: Failed to build gem native extension.
native extensionsとは。
gemでなんとなく予想はついていたけれど、Ruby関係のエラーっぽい。
とはいえ、Rubyは触ったことがないのでよく分からない。
gemが何なのか分からなかったので調べてみると、Rubyのライブラリ？のようだ。
ということは、何かしらの依存関係が原因でエラーが出ている？？
native extensionsについても調べてみると、Ruby以外の言語（C++とか）で書かれているライブラリを参照しているRubyのコードがあるときに発生するエラーらしい（日本語がわかりにくい）。
現時点で分かっている情報を整理すると、gemの一種であるCocoaPodsをインストールしようとしたけど、CocoaPodsと何かの依存関係が原因で、インストールできなかったと。
こういうこと？？

さらに
CocoaPodsが何とうまくいっていないのか調べてみると、RubyとCocoaPodsのバージョンが怪しい。
CocoaPodsの最新バージョンはGitによると1.9.0。
しかし、Mojave(10.14.6)にもともとインストールされているRuby2.3.7では正常に動かないらしい。
Rubyのバージョンを下げるか、インストールするCocoaPodsのバージョンを下げることが解決策になるのか・・・？

結局

$ sudo gem install -v1.8.4 cocoapods -n /usr/local/bin
インストールするCocoaPodsのバージョンを1.9.0の一つ前の1.8.4にを下げました（正確にいうとインストール時にバージョン指定した）。
末尾の-n /usr/local/binは、Mojaveではroot権限を持っているユーザーでもusr直下に何かをインストールできないという制約があるため、-n /usr/local/binでインストール先をデフォルトではない/usr/local/binに明示的に変えています。
