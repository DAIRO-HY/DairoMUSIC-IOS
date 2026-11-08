struct LoginModel : Codable {

  	/** 登录票据 **/
  var token: String

  	/** 会员信息 **/
  var user: UserModel

}
