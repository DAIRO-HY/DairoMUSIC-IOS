enum HomeApi {

  //首页轮播
  static func swiper() -> ApiHttp<[SwiperModel]>{
    return ApiHttp<[SwiperModel]>(ApiConst.HOME_SWIPER,method: "GET")
  }

  //推荐歌单分组
  static func useful() -> ApiHttp<[UsefulModel]>{
    return ApiHttp<[UsefulModel]>(ApiConst.HOME_USEFUL,method: "GET")
  }
}
