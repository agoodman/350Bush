//
//  ImageManager.swift
//  350Bush
//
//  Created by Aubrey Goodman on 9/9/16.
//  Copyright © 2016 Aubrey Goodman. All rights reserved.
//

import Foundation
import UIKit

class ImageManager : NSObject, NSURLSessionDelegate {
  
  static let sharedInstance = ImageManager(baseUrl: "https://s3-us-west-1.amazonaws.com/bushst",
                                           cachePath: NSHomeDirectory() + "/Library/Caches/350Bush")
  
  var baseUrl: String
  var manifestUrl: String
  var cachePath: String
  var manifestPath: String
  var cache: NSCache
  var hashCodeCache: NSCache
  var pendingUrls: NSMutableSet
  var activeTasks: [NSURLSessionTask] = []
  var session: NSURLSession
  var sessionQueue: NSOperationQueue
  
  var gridSize: UInt = 0
  var delta: UInt8 = 5
  var cancelOnFetch: Bool = true

  init(baseUrl: String, cachePath: String) {
    self.baseUrl = baseUrl
    self.manifestUrl = baseUrl + "/manifest.json"
    self.cachePath = cachePath
    self.manifestPath = cachePath + "/manifest.json"
    cache = NSCache.init()
    hashCodeCache = NSCache.init()
    pendingUrls = NSMutableSet.init(capacity: 10)
    sessionQueue = NSOperationQueue.init()
    session = NSURLSession.sharedSession()
  }
  
  // fetches a rectangular range of images of the given quality
  // runs on the main queue
  // dispatches fetching operations to the background queue
  // dispatches callbacks to the main queue
  func fetchRange(iRange: Range<UInt8>, jRange: Range<UInt8>, quality: Quality, progress: (UInt,UInt) -> (), callback: Bool -> ()) {
    if( self.cancelOnFetch ) {
      // cancel any pending tasks before queueing new set
      if( self.activeTasks.count > 0 ) {
        NSLog("ImageManager.cancelActiveTasks")
        for task in self.activeTasks {
          task.cancel()
        }
        self.session.invalidateAndCancel()
        self.activeTasks.removeAll()
        self.pendingUrls.removeAllObjects()
      }
    }
    
    NSLog("ImageManager.fetchRange %d...%d, %d...%d", iRange.startIndex, iRange.endIndex, jRange.startIndex, jRange.endIndex)
    let targetQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)
  
    // construct requests for the specified rectangular range
    var requests : [FetchRequest] = []
    requests.reserveCapacity(iRange.count*jRange.count)
    
    for i in iRange {
      for j in jRange {
        let request : FetchRequest = FetchRequest.init(i: i, j: j, isThumb: true)
        requests.append(request)
      }
    }

    // track request processing progress
    let totalRequests : UInt = UInt(requests.count)
    var completedRequests : UInt = 0
    
    // use a dispatch group to batch the requests with a single callback at the end
    let batchGroup: dispatch_group_t = dispatch_group_create()

    for request in requests {
      dispatch_group_enter(batchGroup)
      dispatch_group_async(batchGroup, targetQueue) {
        let urlString : String = self.baseUrl + "/" + request.urlString(quality)
        self.downloadImageAtUrl(urlString) {
          (success: Bool) in
          
          dispatch_async(dispatch_get_main_queue()) {
            completedRequests += 1
            progress(completedRequests, totalRequests)
          }
          dispatch_group_leave(batchGroup)
        }
      }
    }
    
    dispatch_group_notify(batchGroup, targetQueue) {
      dispatch_async(dispatch_get_main_queue()) {
        callback(true)
      }
    }
  }
  
  // retrieve manifest and store it in local cache
  // dispatches callback to main queue
  func fetchManifest(callback: Bool -> ()) {
    // dispatch request to background queue
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
      
      if( !self.hasValidCacheDirectory() ) {
        dispatch_async(dispatch_get_main_queue()) {
          callback(false)
        }
        return
      }
      
      let task = self.session.downloadTaskWithURL(NSURL.init(string: self.manifestUrl)!) {
        (fileUrl: NSURL?, response: NSURLResponse?, error: NSError?) in
        
        if( error != nil ) {
          dispatch_async(dispatch_get_main_queue()) {
            callback(false)
          }
          return
        }

        // dispatch file io synchronously to main queue
        dispatch_sync(dispatch_get_main_queue()) {
          let dstUrl = NSURL.fileURLWithPath(self.manifestPath)
          do {
            // always replace the existing manifest with the remote
            if( NSFileManager.defaultManager().fileExistsAtPath(self.manifestPath) ) {
              _ = try NSFileManager.defaultManager().replaceItemAtURL(dstUrl, withItemAtURL: fileUrl!, backupItemName: nil, options: NSFileManagerItemReplacementOptions.UsingNewMetadataOnly, resultingItemURL: nil)
            }
            else {
              _ = try NSFileManager.defaultManager().moveItemAtURL(fileUrl!, toURL: dstUrl)
            }
          } catch let error as NSError {
            NSLog("ImageManager.fetchManifest - unable to move file: %@", error)
            dispatch_async(dispatch_get_main_queue()) {
              callback(false)
            }
            return
          }

          dispatch_async(dispatch_get_main_queue()) {
            callback(true)
          }
        }
      }
      dispatch_sync(dispatch_get_main_queue()) {
        self.activeTasks.append(task)
        task.resume();
      }
      
    }
  }
  
  // reads json data from manifest
  // dispatches callback to main queue
  func loadManifest(callback: Bool -> ()) {
    // dispatch request to background queue
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
      
      let rawJson : NSData = NSData.init(contentsOfFile: self.manifestPath)!
      do {
        let manifest : NSDictionary = try NSJSONSerialization.JSONObjectWithData(rawJson, options: NSJSONReadingOptions.AllowFragments) as! NSDictionary
        let gridSize : NSNumber = manifest["gridSize"] as! NSNumber

        dispatch_async(dispatch_get_main_queue()) {
          self.gridSize = UInt(gridSize.integerValue)
          callback(true)
        }
      } catch let error as NSError {
        NSLog("unable to parse manifest: %@", error)
        dispatch_async(dispatch_get_main_queue()) {
          callback(false)
        }
        return
      }
    }
  }
  
  func loadImage(i: UInt8, j: UInt8, quality: Quality, callback: UIImage -> ()) {
    self.loadImageAtUrl(self.urlForFrame(i, j: j, quality: quality), callback: callback)
  }
  
  // runs on main queue
  func loadImageAtUrl(url: String, callback: UIImage -> ()) {
    // first, check the cache
    let hashCode = generateHashCode(url) as UInt64
    let image = self.cache.objectForKey(NSNumber.init(unsignedLongLong: hashCode))
    if( image != nil ) {
      callback(image as! UIImage)
      return
    }

    downloadImageAtUrl(url, callback: {
      (success: Bool) in
      
      if( success ) {
        self.loadImageFromFile(url, callback: callback)
      }
    })
  }
  
  // download image at given url to cache.
  // then, load image from local cache
  private func downloadImageAtUrl(urlString: String, callback: Bool -> ()) {
    // dispatch request to background queue
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
      
      let filePath = self.filePathForUrl(urlString)
      if( filePath == "" ) {
        dispatch_async(dispatch_get_main_queue()) {
          callback(false)
        }
        return
      }

      var fileExists : Bool = false
      var isPending : Bool = false
      dispatch_sync(dispatch_get_main_queue()) {
        fileExists = self.fileExists(filePath)
        isPending = self.pendingUrls.containsObject(urlString)
      }
      
      if( fileExists ) {
        dispatch_async(dispatch_get_main_queue()) {
          callback(true)
        }
        return
      }
      
      if( isPending ) {
        dispatch_async(dispatch_get_main_queue()) {
          callback(false)
        }
        return
      }

      dispatch_sync(dispatch_get_main_queue()) {
        self.pendingUrls.addObject(urlString)
      }
      
      let remoteUrl = NSURL.init(string: urlString)
      let task = self.session.downloadTaskWithURL(remoteUrl!) {
        (fileUrl: NSURL?, response: NSURLResponse?, error: NSError?) in
        
        dispatch_sync(dispatch_get_main_queue()) {
          self.pendingUrls.removeObject(urlString)
        }

        if( error != nil ) {
          if( error?.code == -999 ) {
            // cancelled task; ignore the error
          }
          else {
            NSLog("unable to download image %@", error!)
          }
          dispatch_async(dispatch_get_main_queue()) {
            callback(false)
          }
          return
        }
        
        let httpResponse = response as! NSHTTPURLResponse
        if( httpResponse.statusCode == 404 ) {
          NSLog("404 NOT FOUND: %@", urlString)
          dispatch_async(dispatch_get_main_queue()) {
            callback(false)
          }
          return
        }
        
        if( httpResponse.statusCode == 403 ) {
          NSLog("403 FORBIDDEN: %@", urlString)
          dispatch_async(dispatch_get_main_queue()) {
            callback(false)
          }
          return
        }
        
        // synchronously move file to caches directory
        // NOTE: can't dispatch this to a different queue because file is deleted
        //       immediately after completion block executes
        
        dispatch_sync(dispatch_get_main_queue()) {
          let dstUrl = NSURL.fileURLWithPath(filePath)
          do {
            _ = try NSFileManager.defaultManager().moveItemAtURL(fileUrl!, toURL: dstUrl)
          } catch let error as NSError {
            NSLog("ImageManager.downloadImage - unable to move file: %@", error)
            dispatch_async(dispatch_get_main_queue()) {
              callback(false)
            }
            return
          }
          
          dispatch_async(dispatch_get_main_queue()) {
            callback(true)
          }
        }
      }
      
      dispatch_sync(dispatch_get_main_queue()) {
        self.activeTasks.append(task)
        task.resume()
      }
    }
  }
  
  // load image from local cache, based on urlString
  // dispatches callback to main queue
  private func loadImageFromFile(urlString: String, callback: UIImage -> ()) {
    // dispatch request to background queue
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {

      let filePath = self.filePathForUrl(urlString)
      if( filePath == "" ) {
        // abort! empty file path. do not execute callback
        return
      }

      let imageData : NSData = NSData.init(contentsOfFile: filePath)!
      let image = UIImage.init(data: imageData)
      let key = NSNumber.init(unsignedLongLong: self.generateHashCode(urlString))

      dispatch_async(dispatch_get_main_queue()) {
        self.cache.setObject(image!, forKey: key)
        callback(image!)
      }
    }
  }
  
  // generates a rudimentary hash code from the string
  private func generateHashCode(src: String) -> UInt64 {
    let cachedValue = self.hashCodeCache.objectForKey(src) as! NSNumber?
    if( cachedValue != nil ) {
      return (cachedValue?.unsignedLongLongValue)!
    }
    
    let length = src.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
    var val = 7 as UInt64
    let factoringPrime = 85839547 as UInt64
    for k in 0...length-1 {
      let index = src.startIndex.advancedBy(k)
      let char = src[index] as Character
      let utf8 = char.UTF8()
      let result = UInt64.multiplyWithOverflow(val, factoringPrime)
      val = result.0 + UInt64(utf8)
    }
    return val
  }
  
  private func fileExists(filePath: String) -> Bool {
    if( NSFileManager.defaultManager().fileExistsAtPath(filePath) ) {
      return true
    }
    return false
  }
  
  // generates a file path mapping to the given urlString
  private func filePathForUrl(urlString: String) -> String {
    if( !hasValidCacheDirectory() || urlString == "" ) {
      return ""
    }
    
    let hashCode = generateHashCode(urlString) as UInt64
    let filePath = cachePath + "/" + String(hashCode) + ".jpg"
    return filePath
  }
  
  private func hasValidCacheDirectory() -> Bool {
    var isValid : ObjCBool = true
    dispatch_sync(dispatch_get_main_queue()) {
      if( !NSFileManager.defaultManager().fileExistsAtPath(self.cachePath, isDirectory: &isValid) || !isValid ) {
        do {
          _ = try NSFileManager.defaultManager().createDirectoryAtPath(self.cachePath, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
          NSLog("unable to initialize caches directory: %@", error)
          isValid = false
        }
      }
    }
    return isValid.boolValue
  }
  
  private func urlForFrame(i: UInt8, j: UInt8, quality: Quality) -> String {
    let qualityStr = (quality == .Full ? "full" : "thumb")
    let urlString = self.baseUrl + String.init(format: "/grid/%@/%02d-%02d.jpg", qualityStr, i, j)
    return urlString
  }
  
}

struct Batch {
  var requests: [FetchRequest]
}

struct FetchRequest {
  
  var i: UInt8
  var j: UInt8
  var isThumb: Bool
  
  init(i: UInt8, j: UInt8, isThumb: Bool) {
    self.i = i
    self.j = j
    self.isThumb = isThumb
  }
  
  func urlString(quality: Quality) -> String {
    let qualityStr = (quality == .Full ? "full" : "thumb")
    return String.init(format: "grid/%@/%02d-%02d.jpg", qualityStr, i, j)
  }
  
}

enum Quality {
  case Thumb
  case Full
}
