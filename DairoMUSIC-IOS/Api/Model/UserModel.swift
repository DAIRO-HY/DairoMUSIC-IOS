struct UserModel : Codable {

  	/** 会员ID **/
  var id: Int64

  	/** 邮箱,临时会员为空 **/
  var email: String?

  	/** 昵称 **/
  var nick: String?

  	/** 头像地址 **/
  var logo: String?

  	/** 是否临时会员(还没有绑定邮箱) **/
  var isTemp: Bool

  	/** 是否信赖用户(纠错直接生效) **/
  var isFriend: Bool

}
