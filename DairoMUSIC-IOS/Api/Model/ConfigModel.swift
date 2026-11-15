struct ConfigModel: Codable {

    /// 服务器版本
    var version: String

    /// 服务器ID,服务器换了地址之后依然不变
    var serverId: String

    /// 是否开放注册,关闭时隐藏注册和免注册使用
    var allowRegister: Bool

    /// 是否允许把下载的视频保存到相册,VIP功能生效时只有VIP才能用
    var allowSaveAlbum: Bool

    /// 是否允许把下载的歌曲、视频文件通过隔空投送、其他App发送出去,VIP功能生效时只有VIP才能用
    var allowSendFile: Bool

    /// 服务器是否开启了视频采集,没有开启时不会采集、转码新的视频
    var videoEnable: Bool
}
