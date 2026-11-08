struct AppVersionModel : Codable {

  	/** 版本名 **/
  var versionName: String

  	/** 版本号 **/
  var versionCode: Int

  	/** 安装方式 1:手动安装 2:弹框提示,后台下载 3:强制更新,后台下载 **/
  var installType: Int

  	/** 更新说明 **/
  var instruction: String?

  	/** 下载地址 **/
  var url: String

}
