import Foundation

enum VipApi {

  //兑换VIP,cardNo:卡号(可以带空格、横线) cardPwd:卡密(不区分大小写) confirm:会员已经确认(已经是永久VIP时需要确认)
  static func redeem(cardNo: String,cardPwd: String,confirm: Bool) -> ApiHttp<VipRedeemModel>{
    var parameter: [String : Codable] = ["cardNo":cardNo,"cardPwd":cardPwd]
    if confirm{
      parameter["confirm"] = 1
    }
    return ApiHttp<VipRedeemModel>(ApiConst.VIP_REDEEM,method: "POST",parameter: parameter)
  }
}
