//
//  Session.swift
//  reddift
//
//  Created by sonson on 2015/04/14.
//  Copyright (c) 2015年 sonson. All rights reserved.
//

import UIKit

enum UserSort {
    case Hot
    case New
    case Top
    case Controversial
    
    var path:String {
        get {
            switch self{
            case .Hot:
                return "hot"
            case .New:
                return "new"
            case .Top:
                return "top"
            case .Controversial:
                return "controversial"
            }
        }
    }
}

enum UserContent {
    case Overview
    case Submitted
    case Comments
    case Liked
    case Disliked
    case Hidden
    case Saved
    case Gilded
    
    var path:String {
        get {
            switch self{
            case .Overview:
                return "/overview"
            case .Submitted:
                return "/submitted"
            case .Comments:
                return "/comments"
            case .Liked:
                return "/liked"
            case .Disliked:
                return "/disliked"
            case .Hidden:
                return "/hidden"
            case .Saved:
                return "/saved"
            case .Gilded:
                return "/glided"
            }
        }
    }
}

func parseThing_t2_JSON(json:JSON) -> Result<JSON> {
    if let object = json >>> JSONObject {
        return resultFromOptional(Parser.parseDataInThing_t2(object), NSError())
    }
    return resultFromOptional(nil, NSError())
}

func parseJSON(json:JSON) -> Result<JSON> {
    let object:AnyObject? = Parser.parseJSON(json, depth:0)
    return resultFromOptional(object, NSError())
}

class Session {
    let token:OAuth2Token
    static let baseURL = "https://oauth.reddit.com"
    let URLSession:NSURLSession
    
    var x_ratelimit_reset = 0
    var x_ratelimit_used = 0
    var x_ratelimit_remaining = 0
    
    init(token:OAuth2Token) {
        self.token = token
        self.URLSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
    }
    
    func updateRateLimitWithURLResponse(response:NSURLResponse) {
        if let httpResponse:NSHTTPURLResponse = response as? NSHTTPURLResponse {
            if let temp = httpResponse.allHeaderFields["x-ratelimit-reset"] as? Int {
                x_ratelimit_reset = temp
            }
            if let temp = httpResponse.allHeaderFields["x-ratelimit-used"] as? Int {
                x_ratelimit_used = temp
            }
            if let temp = httpResponse.allHeaderFields["x-ratelimit-remaining"] as? Int {
                x_ratelimit_remaining = temp
            }
        }
    }
    
    func handleRequest(request:NSMutableURLRequest, completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { (data:NSData!, response:NSURLResponse!, error:NSError!) -> Void in
            let responseResult = Result(error, Response(data: data, urlResponse: response))
            let result = responseResult >>> parseResponse >>> decodeJSON >>> parseJSON
            completion(result)
        })
        task.resume()
        return task
    }
	
	func getMessage(messageWhere:MessageWhere, completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
		var request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(Session.baseURL, path:"/message" + messageWhere.path, method:"GET", token:token)
		return handleRequest(request, completion:completion)
	}
    
    func getProfile(completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        var request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(Session.baseURL, path:"/api/v1/me", method:"GET", token:token)
        let task = URLSession.dataTaskWithRequest(request, completionHandler: { (data:NSData!, response:NSURLResponse!, error:NSError!) -> Void in
            let responseResult = Result(error, Response(data: data, urlResponse: response))
            let result = responseResult >>> parseResponse >>> decodeJSON >>> parseThing_t2_JSON
            completion(result)
        })
        task.resume()
        return task
    }
    
    func getArticles(paginator:Paginator?, link:Link, sort:CommentSort, completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        if paginator == nil {
            return nil
        }
        var parameter:[String:String] = ["sort":sort.type, "depth":"2"]
        var request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(Session.baseURL, path:"/comments/" + link.id, parameter:parameter, method:"GET", token:token)
        return handleRequest(request, completion:completion)
    }
    
    func getSubscribingSubreddit(paginator:Paginator?, completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        var request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(Session.baseURL, path:SubredditsWhere.Subscriber.path, parameter:paginator?.parameters(), method:"GET", token:token)
        return handleRequest(request, completion:completion)
    }
    
    func getList(paginator:Paginator?, sort:LinkSort, subreddit:Subreddit?, completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        if paginator == nil {
            return nil
        }
        var path = sort.path
        if let subreddit = subreddit {
            path = "/r/\(subreddit.display_name)\(path)"
        }
        var request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(Session.baseURL, path:path, parameter:paginator?.parameters(), method:"GET", token:token)
        return handleRequest(request, completion:completion)
    }
    
    func getUser(username:String, content:UserContent, paginator:Paginator?, completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        var request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(Session.baseURL, path:"/user/" + username + content.path, method:"GET", token:token)
        return handleRequest(request, completion:completion)
    }
    
    func getInfo(names:[String], completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        var commaSeparatedNameString = commaSeparatedStringFromList(names)
        var request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(Session.baseURL, path:"/api/info", parameter:["id":commaSeparatedNameString], method:"GET", token:token)
        return handleRequest(request, completion:completion)
    }
    
    func getInfo(name:String, completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        return getInfo([name], completion: completion)
    }
    
    /**
    DOES NOT WORK... WHY?
    */
    func getSticky(subreddit:Subreddit, completion:(Result<JSON>) -> Void) -> NSURLSessionDataTask? {
        var request = NSMutableURLRequest.mutableOAuthRequestWithBaseURL(Session.baseURL, path:"/r/" + subreddit.display_name + "/sticky", method:"GET", token:token)
        return handleRequest(request, completion:completion)
    }
}