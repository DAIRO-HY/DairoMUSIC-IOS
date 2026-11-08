struct UsefulModel : Codable, Hashable {

  	/** 分组名 **/
  var name: String?

  	/** 显示方式 1:表格 2:横向滚动 **/
  var type: Int

  	/** 歌单 **/
  var favorites: [FavoriteModel]

}
