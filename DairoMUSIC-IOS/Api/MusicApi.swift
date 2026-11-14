enum MusicApi {

  //从曲库搜索,最多30条
  static func search(key: String) -> ApiHttp<[MusicModel]>{
    return ApiHttp<[MusicModel]>(ApiConst.MUSIC_SEARCH,method: "GET",parameter: ["key":key])
  }

  //从采集平台搜索,结果的id为0
  static func searchCollect(key: String) -> ApiHttp<[MusicModel]>{
    return ApiHttp<[MusicModel]>(ApiConst.MUSIC_SEARCH_COLLECT,method: "GET",parameter: ["key":key])
  }

  //歌曲详情
  static func detail(id: Int64) -> ApiHttp<MusicModel>{
    return ApiHttp<MusicModel>(ApiConst.MUSIC_DETAIL,method: "GET",parameter: ["id":id])
  }

  //歌词列表
  static func lrc(id: Int64) -> ApiHttp<[MusicLrcModel]>{
    return ApiHttp<[MusicLrcModel]>(ApiConst.MUSIC_LRC,method: "GET",parameter: ["id":id])
  }

  //歌曲视频,没有采集或者可以重试的失败时会开始采集,采集和转码过程中每3秒查询一次
  static func video(id: Int64) -> ApiHttp<VideoModel>{
    return ApiHttp<VideoModel>(ApiConst.MUSIC_VIDEO,method: "GET",parameter: ["id":id])
  }

  //提交播放记录,ids为播放完成的歌曲ID,逗号分隔,播放了几次就出现几次,一次最多500个
  static func play(ids: String) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.MUSIC_PLAY,method: "POST",parameter: ["ids":ids])
  }

  //采集平台的歌曲加入曲库,返回歌曲ID
  static func collect(name: String,logo: String?,platform: String,extra: String) -> ApiHttp<Int64>{
    var parameter: [String : Codable] = ["name":name,"platform":platform,"extra":extra]
    if let logo{
      parameter["logo"] = logo
    }
    return ApiHttp<Int64>(ApiConst.MUSIC_COLLECT,method: "POST",parameter: parameter)
  }

  //纠错,只提交要修改的字段
  static func correct(id: Int64,name: String,artist: String,album: String) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.MUSIC_CORRECT,method: "POST",parameter: ["id":id,"name":name,"artist":artist,"album":album])
  }

  //投诉
  static func complaint(id: Int64,content: String) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.MUSIC_COMPLAINT,method: "POST",parameter: ["id":id,"content":content])
  }

  //投诉理由的选项
  static func complaintSamples() -> ApiHttp<[String]>{
    return ApiHttp<[String]>(ApiConst.MUSIC_COMPLAINT_SAMPLES,method: "GET")
  }
}
