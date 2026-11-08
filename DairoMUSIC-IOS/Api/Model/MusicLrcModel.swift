struct MusicLrcModel : Codable {

  	/** 歌词ID **/
  var id: Int64

  	/** 歌词标题 **/
  var title: String?

  	/** 歌词内容,LRC或者WEBVTT格式 **/
  var lrc: String?

}
