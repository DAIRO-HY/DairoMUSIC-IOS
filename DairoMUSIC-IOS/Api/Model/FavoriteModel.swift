struct FavoriteModel : Codable, Hashable {

  	/** 歌单ID **/
  var id: Int64

  	/** 歌单名 **/
  var name: String

  	/** 描述 **/
  var description: String?

  	/** 封面地址,"我喜欢"歌单为空 **/
  var logo: String?

  	/** 是否"我喜欢"歌单,不能删除、不能改名 **/
  var isLike: Bool

  	/** 歌曲数 **/
  var musicCount: Int

  	/** 是否自己的歌单 **/
  var isMine: Bool

}
