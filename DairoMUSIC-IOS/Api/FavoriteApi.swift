import Foundation

enum FavoriteApi {

  //我的歌单
  static func list() -> ApiHttp<[FavoriteModel]>{
    return ApiHttp<[FavoriteModel]>(ApiConst.FAVORITE_LIST,method: "GET")
  }

  //歌单详情
  static func detail(id: Int64) -> ApiHttp<FavoriteModel>{
    return ApiHttp<FavoriteModel>(ApiConst.FAVORITE_DETAIL,method: "GET",parameter: ["id":id])
  }

  //新建歌单,返回歌单ID
  static func add(name: String) -> ApiHttp<Int64>{
    return ApiHttp<Int64>(ApiConst.FAVORITE_ADD,method: "POST",parameter: ["name":name])
  }

  //修改歌单
  static func edit(id: Int64,name: String,description: String) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.FAVORITE_EDIT,method: "POST",parameter: ["id":id,"name":name,"description":description])
  }

  //上传封面,返回封面地址
  static func logo(id: Int64,jpeg: Data) -> ApiHttp<String>{
    return ApiHttp<String>(ApiConst.FAVORITE_LOGO,method: "POST",parameter: ["id":id]).file(name: "file",fileName: "logo.jpg",mimeType: "image/jpeg",data: jpeg)
  }

  //删除歌单
  static func delete(id: Int64) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.FAVORITE_DELETE,method: "DELETE",parameter: ["id":id])
  }

  //歌单排序,ids为排好序的歌单ID
  static func sort(ids: [Int64]) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.FAVORITE_SORT,method: "POST",parameter: ["ids":ids.map{ String($0) }.joined(separator: ",")])
  }

  //歌单里的歌曲,最近添加的在前面
  static func musics(id: Int64) -> ApiHttp<[MusicModel]>{
    return ApiHttp<[MusicModel]>(ApiConst.FAVORITE_MUSICS,method: "GET",parameter: ["id":id])
  }

  //我所有歌单里的歌曲
  static func allMusics() -> ApiHttp<[MusicModel]>{
    return ApiHttp<[MusicModel]>(ApiConst.FAVORITE_ALL_MUSICS,method: "GET")
  }

  //添加歌曲到歌单
  static func addMusic(favoriteId: Int64,musicId: Int64) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.FAVORITE_ADD_MUSIC,method: "POST",parameter: ["favoriteId":favoriteId,"musicId":musicId])
  }

  //从歌单删除歌曲
  static func removeMusic(favoriteId: Int64,musicId: Int64) -> ApiHttp<EmptyModel>{
    return ApiHttp<EmptyModel>(ApiConst.FAVORITE_REMOVE_MUSIC,method: "DELETE",parameter: ["favoriteId":favoriteId,"musicId":musicId])
  }
}
