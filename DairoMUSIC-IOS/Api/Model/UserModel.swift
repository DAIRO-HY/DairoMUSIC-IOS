struct UserModel : Codable {

  	/** 会员ID **/
  var id: Int64

  	/** 邮箱,临时会员为空;后台创建的只有用户名的会员也为空 **/
  var email: String?

  	/** 用户名,只能由后台设置,可以用来登录 **/
  var name: String?

  	/** 昵称 **/
  var nick: String?

  	/** 头像地址 **/
  var logo: String?

  	/** 是否临时会员(还没有绑定邮箱) **/
  var isTemp: Bool

  	/** 是否信赖用户(纠错直接生效) **/
  var isFriend: Bool

  	/** VIP状态,老版本保存的会员信息里没有,按VIP功能没有生效处理 **/
  var vip: VipModel?

}

struct VipModel : Codable, Hashable {

  	/** VIP功能对这个会员是否生效,为false时没有任何限制,不显示VIP相关的内容 **/
  var enable: Bool

  	/** 现在是否VIP **/
  var isVip: Bool

  	/** 是否永久VIP **/
  var forever: Bool

  	/** VIP到期时间(毫秒),0:从来不是VIP,永久VIP时没有意义 **/
  var expireTime: Int64

}

struct VipRedeemModel : Codable {

  	/** 是否需要会员确认,已经是永久VIP时兑换没有实际效果,确认之后带上confirm=1再提交 **/
  var needConfirm: Bool

  	/** 提示文字 **/
  var message: String

  	/** 兑换之后的VIP状态 **/
  var vip: VipModel?

}
