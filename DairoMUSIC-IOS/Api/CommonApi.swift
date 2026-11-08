enum CommonApi {

  //获取服务器的公开配置,不需要登录
  static func config() -> ApiHttp<ConfigModel>{
    return ApiHttp<ConfigModel>(ApiConst.COMMON_CONFIG,method: "GET").noAuth()
  }

  //检查更新,没有新版本时返回nil
  static func checkVersion() -> ApiHttp<AppVersionModel?>{
    return ApiHttp<AppVersionModel?>(ApiConst.APP_VERSION_CHECK,method: "GET",parameter: ["clientFlag":Const.CLIENT_FLAG,"versionCode":Const.versionCode]).noAuth()
  }

  //发送邮箱验证码 type:register:注册 reset_pwd:重置密码 bind_email:绑定邮箱
  static func sendEmailCode(email: String,type: String) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.EMAIL_SEND_CODE,method: "POST",parameter: ["email":email,"type":type]).noAuth()
  }

  //意见反馈,返回给用户看的提示文字
  static func feedback(content: String) -> ApiHttp<String>{
    return ApiHttp<String>(ApiConst.FEEDBACK_ADD,method: "POST",parameter: ["content":content,"clientFlag":Const.CLIENT_FLAG])
  }
}
