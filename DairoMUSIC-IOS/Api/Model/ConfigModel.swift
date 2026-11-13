struct ConfigModel : Codable {

  	/** 服务器版本 **/
  var version: String

  	/** 服务器ID,服务器换了地址之后依然不变 **/
  var serverId: String

  	/** 是否开放注册,关闭时隐藏注册和免注册使用 **/
  var allowRegister: Bool

  	/** 是否允许下载视频,不允许时隐藏视频的下载按钮 **/
  var allowDownloadVideo: Bool

  	/** 是否允许把下载的视频保存到相册,允许下载视频时才有效 **/
  var allowSaveAlbum: Bool

  	/** 是否允许下载歌曲 **/
  var allowDownloadMusic: Bool

  	/** 服务器是否开启了视频采集,没有开启时不会采集、转码新的视频 **/
  var videoEnable: Bool

}
