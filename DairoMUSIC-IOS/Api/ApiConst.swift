/// Api地址
enum ApiConst {

  static let COMMON_CONFIG = "/api/common/config"
  static let APP_VERSION_CHECK = "/api/app_version/check"
  static let EMAIL_SEND_CODE = "/api/email/send_code"

  static let USER_TEMP_LOGIN = "/api/user/temp_login"
  static let USER_LOGIN = "/api/user/login"
  static let USER_REGISTER = "/api/user/register"
  static let USER_RESET_PWD = "/api/user/reset_pwd"
  static let USER_BIND_EMAIL = "/api/user/bind_email"
  static let USER_INFO = "/api/user/info"
  static let USER_EDIT = "/api/user/edit"
  static let USER_AVATAR = "/api/user/avatar"
  static let USER_MODIFY_PWD = "/api/user/modify_pwd"
  static let USER_UNREGISTER = "/api/user/unregister"
  static let USER_LOGOUT = "/api/user/logout"

  static let VIP_REDEEM = "/api/vip/redeem"

  static let MUSIC_SEARCH = "/api/music/search"
  static let MUSIC_SEARCH_COLLECT = "/api/music/search_collect"
  static let MUSIC_DETAIL = "/api/music/detail"
  static let MUSIC_LRC = "/api/music/lrc"
  static let MUSIC_VIDEO = "/api/music/video"
  static let MUSIC_PLAY = "/api/music/play"
  static let MUSIC_COLLECT = "/api/music/collect"
  static let MUSIC_CORRECT = "/api/music/correct"
  static let MUSIC_COMPLAINT = "/api/music/complaint"
  static let MUSIC_COMPLAINT_SAMPLES = "/api/music/complaint_samples"

  static let FAVORITE_LIST = "/api/favorite/list"
  static let FAVORITE_DETAIL = "/api/favorite/detail"
  static let FAVORITE_ADD = "/api/favorite/add"
  static let FAVORITE_EDIT = "/api/favorite/edit"
  static let FAVORITE_LOGO = "/api/favorite/logo"
  static let FAVORITE_DELETE = "/api/favorite/delete"
  static let FAVORITE_SORT = "/api/favorite/sort"
  static let FAVORITE_MUSICS = "/api/favorite/musics"
  static let FAVORITE_ALL_MUSICS = "/api/favorite/all_musics"
  static let FAVORITE_ADD_MUSIC = "/api/favorite/add_music"
  static let FAVORITE_REMOVE_MUSIC = "/api/favorite/remove_music"

  static let HOME_SWIPER = "/api/home/swiper"
  static let HOME_USEFUL = "/api/home/useful"

  static let FEEDBACK_ADD = "/api/feedback/add"

  ///歌曲分享页面
  static let SHARE_MUSIC = "/share/music.html"
}
