struct MusicModel : Codable, Hashable {

  	/** 歌曲ID,采集平台的搜索结果为0 **/
  var id: Int64

  	/** 歌名 **/
  var name: String?

  	/** 歌手 **/
  var artist: String?

  	/** 专辑 **/
  var album: String?

  	/** 封面地址 **/
  var logo: String?

  	/** 时长(毫秒) **/
  var duration: Int64?

  	/** 所在的歌单ID,只有歌单里的歌曲才有 **/
  var favoriteId: Int64?

  	/** 所有音质的歌曲文件,为空表示还没有采集完成 **/
  var files: [MusicFileModel]?

  	/** 采集信息 **/
  var collect: MusicCollectModel?

  	/** 视频状态 0:未采集 1:采集中 2:有视频 3:没有视频 4:视频已删除 5:采集失败 **/
  var videoState: Int?

  	/** 播放次数,只有曲库的搜索结果才有 **/
  var playCount: Int?

}

struct MusicFileModel : Codable, Hashable {

  	/** 文件ID,不会变,用作缓存key **/
  var id: Int64

  	/** 文件的MD5,部分老数据为空 **/
  var md5: String?

  	/** 比特率 **/
  var bitRate: Int?

  	/** 采样率 **/
  var sampleRate: Int?

  	/** 文件大小 **/
  var size: Int64

  	/** 格式 **/
  var format: String

  	/** 播放地址(支持断点续传),非VIP时只有最低音质有地址 **/
  var url: String?

  	/** 是否只有VIP可以播放,非VIP时为true的文件没有播放地址 **/
  var vipOnly: Bool?

}

struct MusicCollectModel : Codable, Hashable {

  	/** 采集平台 **/
  var platform: String

  	/** 采集参数 **/
  var extra: String

  	/** 采集平台的播放地址 **/
  var url: String?

  	/** 采集平台的原画视频地址,可以直接播放 **/
  var videoUrl: String?

  	/** 查询视频是否可以播放,返回OK时可以播放,其他内容是进度说明,第一次请求时开始下载 **/
  var videoInfoUrl: String?

}
