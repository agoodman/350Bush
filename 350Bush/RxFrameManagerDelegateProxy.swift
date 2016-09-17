//
//  RxFrameManagerDelegateProxy.swift
//  350Bush
//
//  Created by Aubrey Goodman on 9/17/16.
//  Copyright © 2016 Aubrey Goodman. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa


public class RxFrameManagerDelegateProxy : DelegateProxy, DelegateProxyType {
  
  public class func currentDelegateFor(object: AnyObject) -> AnyObject? {
    let frameManager : FrameManager = object as! FrameManager
    
    return frameManager.delegate
  }
  
  public class func setCurrentDelegate(delegate: AnyObject?, toObject object: AnyObject) {
    let frameManager : FrameManager = object as! FrameManager
    
    frameManager.delegate = delegate as? FrameManagerDelegate
  }
  
  public override class func createProxyForObject(object : AnyObject) -> AnyObject {
    let frameManager : FrameManager = object as! FrameManager
    
    return frameManager.delegate!
  }
  
}
