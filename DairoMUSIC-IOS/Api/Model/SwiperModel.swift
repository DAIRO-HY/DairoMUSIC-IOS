struct SwiperModel : Codable, Hashable {

  	/** 轮播ID **/
  var id: Int64

  	/** 标题 **/
  var name: String

  	/** 图片地址 **/
  var image: String?

  	/** 类型 1:推荐的歌单(data为歌单ID) 2:推荐单曲(data为歌曲ID) 3:拨打电话 4:跳转网页 **/
  var type: Int

  	/** 数据 **/
  var data: String?

}
