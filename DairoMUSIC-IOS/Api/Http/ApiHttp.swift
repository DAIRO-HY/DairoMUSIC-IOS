//
//  ApiHttp.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import Foundation
import DairoUI_IOS

///api请求基类
protocol ApiHttpBase{
    
    //取消请求
    func cancel()
}

/**
 * API请求
 */
class ApiHttp<T: Codable> : ApiHttpBase{
    
    private let url: String
    
    ///请求方式
    private let method: String
    
    ///API参数
    private let parameter: [String : Codable]
    
    ///http请求任务
    private var httpTask: URLSessionDataTask?
    
    ///是否显示加载中的遮罩层
    private var isShowWaiting = true
    
    ///是否携带登录票据
    private var isAuth = true

    ///指定服务器地址,为nil时使用当前登录的服务器
    private var domain: String?

    ///要上传的文件
    private var uploadFile: ApiUploadFile?
    
    /**
     * 失败时消息回调
     */
    private var failFunc: ((_ failModel: ApiFailModel) -> Void)?
    
    /**
     * 出错时消息回调
     */
    private var errorFunc: ((_ msg: String) -> Void)?
    
    /**
     * 最终回调
     */
    private var finishFunc: (() -> Void)?
    
    init(_ url: String, method: String, parameter: [String : Codable] = [String : Codable]()) {
        self.url = url
        self.method = method
        self.parameter = parameter
    }
    
    /**
     * 请求失败时的回调
     */
    func fail(block: @escaping (_ failModel: ApiFailModel) -> Void) -> ApiHttp {
        self.failFunc = block
        return self
    }
    
    /**
     * 请求异常时的回调
     */
    func error(block: @escaping (_ msg: String) -> Void) -> ApiHttp {
        self.errorFunc = block
        return self
    }
    
    /**
     * 最终回调
     */
    func finish(block: @escaping () -> Void) -> ApiHttp {
        self.finishFunc = block
        return self
    }
    
    /**
     * 不显示等待框
     */
    func hide() -> ApiHttp {
        self.isShowWaiting = false
        return self
    }
    
    /**
     * 不携带登录票据,用于登录等不需要登录的接口
     */
    func noAuth() -> ApiHttp {
        self.isAuth = false
        return self
    }

    /**
     * 请求指定的服务器,用于登录、注册等还没有切换服务器的情况,同时不携带登录票据
     */
    func domain(_ domain: String) -> ApiHttp {
        self.domain = domain
        self.isAuth = false
        return self
    }
    
    /**
     * 以multipart方式上传文件
     */
    func file(name: String, fileName: String, mimeType: String, data: Data) -> ApiHttp {
        self.uploadFile = ApiUploadFile(name: name, fileName: fileName, mimeType: mimeType, data: data)
        return self
    }
    
    /**
     * 调用失败函数
     */
    private func callFail(_ failModel: ApiFailModel) {
        if self.failFunc != nil {
            self.failFunc!(failModel)
        } else {
            if self.isShowWaiting{//有遮照层
                Toast.show(failModel.msg ?? "处理失败")
            }
        }
    }
    
    /**
     * 调用出错函数
     */
    private func callError(_ msg: String) {
        if (self.errorFunc != nil) {
            self.errorFunc!(msg)
        } else {
            if self.isShowWaiting{//有遮照层
                Toast.show(msg)
            }
        }
    }
    
    /**
     * 发起请求
     * 带参回调
     * - paramter successFunc  成功的返回值
     */
    @discardableResult
    func send(_ successFunc: @escaping (_ data: T) -> Void)  -> ApiHttp{
        self.request(successFunc)
        return self
    }
    
    /**
     * 发起请求
     * 无参回调
     * - paramter successFunc  成功的返回值
     */
    @discardableResult
    func send(_ successFunc: @escaping () -> Void)  -> ApiHttp{
        self.request{_ in
            successFunc()
        }
        return self
    }
    
    /**
     * 发起请求
     */
    private func request(_ successFunc: @escaping((_ data: T) -> Void)) {
        let parameterStr = self.parameterStr
        var urlStr = (self.domain ?? SettingShared.domainNotNull) + self.url
        if self.method == "GET" && !parameterStr.isEmpty{
            urlStr += "?" + parameterStr
        }
        guard let url = URL(string: urlStr) else{
            self.callError("服务器地址不正确:" + urlStr)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = self.method//请求方式
        request.timeoutInterval = 15 // 设置超时(秒)
        if self.isAuth{
            request.setValue("Bearer " + SettingShared.token, forHTTPHeaderField: "Authorization")
        }
        if let uploadFile = self.uploadFile{
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=" + boundary, forHTTPHeaderField: "Content-Type")
            request.httpBody = uploadFile.multipartBody(boundary: boundary, parameter: self.parameter)
        } else if self.method != "GET" && !parameterStr.isEmpty{
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = parameterStr.data(using: .utf8)
        }
        let httpTask = URLSession.shared.dataTask(with: request){ data, response, error in
            
            //数据量可能很大,解析不能放在主线程
            let result = (response as? HTTPURLResponse)?.statusCode == 200 ? self.convert(data ?? Data()) : nil
            
            //使回调函数运行在主线程上
            Task{@MainActor in
                if self.isShowWaiting{
                    Loading.hide()
                }
                if let error = error as? URLError, error.code == .cancelled{//请求被取消
                    return
                }
                defer{
                    self.finishFunc?()
                }
                if let error = error {
                    self.callError(error.localizedDescription)
                    return
                }
                self.onResponse(response as! HTTPURLResponse, data ?? Data(), result, successFunc)
            }
        }
        self.httpTask = httpTask
        
        //如果需要显示等待框
        if self.isShowWaiting{
            Loading.show()
        }
        httpTask.resume()
    }
    
    /**
     * 将参数拼接成字符串,数组参数使用重复的key
     */
    private var parameterStr: String{
        var items = [String]()
        for entry in self.parameter{
            let values: [Any]
            if let value = entry.value as? [any Codable]{
                values = value
            } else {
                values = [entry.value]
            }
            for value in values{
                items.append(ApiHttp.encode(entry.key) + "=" + ApiHttp.encode("\(value)"))
            }
        }
        return items.joined(separator: "&")
    }
    
    /**
     * 对参数进行URL编码
     */
    private static func encode(_ value: String) -> String{
        return value.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "-._~").union(.alphanumerics)) ?? value
    }
    
    /**
     * 处理服务器返回结果
     * 200:成功 401:登录失效 其他:失败,返回内容是错误信息
     */
    private func onResponse(_ response: HTTPURLResponse, _ data: Data, _ result: T?, _ successFunc: (_ data: T) -> Void){
        if response.statusCode == 200{
            guard let t = result else{
                self.callError("服务器返回数据格式不正确")
                return
            }
            successFunc(t)
            return
        }
        if response.statusCode == 401 && self.isAuth && SettingShared.isLogin{
            Toast.show("登录已失效,请重新登录")
            SettingShared.toLoginPage()
            return
        }
        self.callFail(self.makeFailModel(response.statusCode, data))
    }
    
    /**
     * 生成失败信息,表单验证失败时优先显示字段的错误信息
     * 需要登录的接口没有权限时返回403或404,这两种情况的返回内容不适合直接显示给用户
     */
    private func makeFailModel(_ statusCode: Int, _ data: Data) -> ApiFailModel{
        if self.isAuth && statusCode == 403{
            return ApiFailModel(code: statusCode, msg: "没有操作权限")
        }
        if self.isAuth && statusCode == 404{
            return ApiFailModel(code: statusCode, msg: "内容不存在或没有访问权限")
        }
        if let formFail = try? JSONDecoder().decode(ApiFormFailModel.self, from: data){
            let msg = formFail.data?.values.first{ !$0.isEmpty }?.first ?? formFail.msg
            return ApiFailModel(code: statusCode, msg: msg)
        }
        let msg = String(data: data, encoding: .utf8) ?? ""
        return ApiFailModel(code: statusCode, msg: msg.isEmpty ? nil : msg)
    }
    
    /**
     * 将返回值转换成指定的类型
     */
    private func convert(_ data: Data) -> T?{
        switch(T.self){
        case is String.Type:
            return String(data: data, encoding: .utf8) as? T
        case is Bool.Type:
            return (String(data: data, encoding: .utf8)?.lowercased() == "true") as? T
        case is EmptyModel.Type:
            return EmptyModel() as? T
        default:
            return try? JSONDecoder().decode(T.self, from: data)
        }
    }
    
    /**
     * 取消请求
     */
    func cancel(){
        self.httpTask?.cancel()
    }
    
    deinit{
        debugPrint("-->ApiHttp:deinit")
    }
}


/**
 * 要上传的文件
 */
private struct ApiUploadFile {
    let name: String
    let fileName: String
    let mimeType: String
    let data: Data
    
    /**
     * 生成multipart请求内容,普通参数放在文件前面
     */
    func multipartBody(boundary: String, parameter: [String : Codable]) -> Data {
        var body = Data()
        for entry in parameter{
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(entry.key)\"\r\n\r\n".utf8))
            body.append(Data("\(entry.value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(self.name)\"; filename=\"\(self.fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(self.mimeType)\r\n\r\n".utf8))
        body.append(self.data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}

/**
 * 不需要返回结果的Model
 */
struct EmptyModel: Codable {
}

/**
 * API返回失败Model
 */
struct ApiFailModel: Codable {
    
    /**
     * HTTP状态码
     */
    let code: Int
    
    /**
     * 错误信息
     */
    let msg: String?
}

/**
 * 表单验证失败Model
 */
private struct ApiFormFailModel: Codable {
    
    /**
     * 错误信息
     */
    let msg: String?
    
    /**
     * 字段名 => 错误信息
     */
    let data: [String : [String]]?
}


/**
 * Api请求Error
 */
struct ApiFailError : Error{
    let failModel: ApiFailModel
}

