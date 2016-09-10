//
//  FrameViewController.swift
//  350Bush
//
//  Created by Aubrey Goodman on 9/9/16.
//  Copyright © 2016 Aubrey Goodman. All rights reserved.
//

import Foundation
import UIKit

class FrameViewController : UIViewController {
  
  @IBOutlet var imageView: UIImageView?
  var i: UInt8 = 0
  var j: UInt8 = 0
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    ImageManager.sharedInstance.fetchManifest() {
      (success: Bool) in
      
      if( !success ) {
        NSLog("ImageManager.fetchManifest FAIL")
        return
      }
      
      NSLog("ImageManager.fetchManifest OK")
      self.loadManifestContents()
    }
  }
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
  }
  
  private func preloadThumbs() {
  
    let delta : UInt8 = ImageManager.sharedInstance.delta
    let iRange : Range = createRange(self.i, delta: delta)
    let jRange : Range = createRange(self.j, delta: delta)
    ImageManager.sharedInstance.fetchThumbs(iRange, jRange: jRange, progress: {
      (complete: UInt, total: UInt) in
      
      NSLog("progress: %d of %d", complete, total)
    }) {
      (success: Bool) in
      
      let val = success ? "OK" : "FAIL"
      NSLog("ImageManager.preloadThumbs %@", val)
    }
    
  }
  
  private func loadManifestContents() {
    
    ImageManager.sharedInstance.loadManifest() {
      (success: Bool) in
      
      if( !success ) {
        NSLog("ImageManager.loadManifest FAIL")
        return
      }
      
      NSLog("ImageManager.loadManifest OK (size: %d)", ImageManager.sharedInstance.gridSize)
      self.i = UInt8(ImageManager.sharedInstance.gridSize / 2)
      self.j = self.i
      self.preloadThumbs()
    }
    
  }
  
  private func createRange(val: UInt8, delta: UInt8) -> Range<UInt8> {
    let sizeMax = ImageManager.sharedInstance.gridSize - 1
    let vminResult = Int.addWithOverflow(Int(val), -Int(delta))
    let vmin = max(vminResult.0, 0)
    let vmaxResult = Int.addWithOverflow(Int(val), Int(delta))
    let vmax = min(vmaxResult.0, Int(sizeMax))
    return UInt8(vmin)...UInt8(vmax)
  }
}

