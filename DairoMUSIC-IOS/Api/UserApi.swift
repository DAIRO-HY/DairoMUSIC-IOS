import Foundation

enum UserApi {

  //登录时需要的设备信息
  private static var deviceParameter: [String : Codable]{
    return ["deviceId":Const.deviceId,"clientFlag":Const.CLIENT_FLAG,"clientVersion":Const.versionCode]
  }

  //免注册使用,同一台设备找回同一个临时会员
  static func tempLogin() -> ApiHttp<LoginModel>{
    return ApiHttp<LoginModel>(ApiConst.USER_TEMP_LOGIN,method: "POST",parameter: UserApi.deviceParameter).noAuth()
  }

  //登录,account为邮箱或用户名(用户名不区分大小写),pwd为明文密码
  static func login(account: String,pwd: String) -> ApiHttp<LoginModel>{
    var parameter = UserApi.deviceParameter
    parameter["account"] = account
    parameter["pwd"] = pwd
    return ApiHttp<LoginModel>(ApiConst.USER_LOGIN,method: "POST",parameter: parameter).noAuth()
  }

  //注册,注册后直接登录
  static func register(email: String,pwd: String,code: String) -> ApiHttp<LoginModel>{
    var parameter = UserApi.deviceParameter
    parameter["email"] = email
    parameter["pwd"] = pwd
    parameter["code"] = code
    return ApiHttp<LoginModel>(ApiConst.USER_REGISTER,method: "POST",parameter: parameter).noAuth()
  }

  //重置密码,所有设备需要重新登录
  static func resetPwd(email: String,code: String,pwd: String) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.USER_RESET_PWD,method: "POST",parameter: ["email":email,"code":code,"pwd":pwd]).noAuth()
  }

  //绑定邮箱:临时会员绑定之后成为正式会员,pwd为新的登录密码;只有用户名没有邮箱的会员pwd为当前的登录密码,用来确认身份,密码不会修改
  static func bindEmail(email: String,code: String,pwd: String) -> ApiHttp<UserModel>{
    return ApiHttp<UserModel>(ApiConst.USER_BIND_EMAIL,method: "POST",parameter: ["email":email,"code":code,"pwd":pwd])
  }

  //会员信息
  static func info() -> ApiHttp<UserModel>{
    return ApiHttp<UserModel>(ApiConst.USER_INFO,method: "GET")
  }

  //修改昵称
  static func edit(nick: String) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.USER_EDIT,method: "POST",parameter: ["nick":nick])
  }

  //上传头像,返回头像地址;不限大小,服务器会居中裁切成正方形并缩小
  static func avatar(jpeg: Data) -> ApiHttp<String>{
    return ApiHttp<String>(ApiConst.USER_AVATAR,method: "POST").file(name: "file",fileName: "avatar.jpg",mimeType: "image/jpeg",data: jpeg)
  }

  //修改密码,其他设备需要重新登录
  static func modifyPwd(oldPwd: String,pwd: String) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.USER_MODIFY_PWD,method: "POST",parameter: ["oldPwd":oldPwd,"pwd":pwd])
  }

  //注销账号
  static func unregister(pwd: String) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.USER_UNREGISTER,method: "POST",parameter: ["pwd":pwd])
  }

  //退出登录
  static func logout() -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.USER_LOGOUT,method: "DELETE")
  }
}
