struct VideoModel : Codable {

  	/** 视频状态 0:未采集 1:采集中 2:有视频 3:没有视频 4:视频已删除 5:采集失败 **/
  var state: Int

  	/** 原画 **/
  var original: VideoFileModel?

  	/** 流畅(480p 25fps),原画不高于480p 25fps时和原画是同一个文件 **/
  var smooth: VideoFileModel?

}

struct VideoFileModel : Codable, Hashable {

  	/** 文件ID,不会变,用作缓存key **/
  var id: Int64

  	/** 清晰度 1:原画 2:流畅 **/
  var quality: Int

  	/** 状态 0:转码中 1:可以播放 2:失败 **/
  var state: Int

  	/** 宽 **/
  var width: Int?

  	/** 高 **/
  var height: Int?

  	/** 比特率(kbps) **/
  var bitRate: Int?

  	/** 时长(毫秒) **/
  var duration: Int64?

  	/** 文件大小 **/
  var size: Int64?

  	/** 文件MD5 **/
  var md5: String?

  	/** 播放地址 **/
  var url: String?

}
