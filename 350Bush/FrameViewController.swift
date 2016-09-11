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
  
  let panThreshold : Float = 4
  
  @IBOutlet var imageView: UIImageView?
  var i: UInt8 = 0
  var j: UInt8 = 0
  var lastUpdateTime: NSDate = NSDate.init()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // create pan gesture recognizer to track touches
    let recognizer : UIPanGestureRecognizer = UIPanGestureRecognizer.init(target: self, action: Selector("handlePan:"))
    self.view.addGestureRecognizer(recognizer)
    
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
  
  @IBAction func up() {
    if( self.i < UInt8(ImageManager.sharedInstance.gridSize) - 1 ) {
      self.i += 1
    }
    self.loadCurrentFrame()
    self.preloadThumbs()
  }
  
  @IBAction func down() {
    if( self.i > 0 ) {
      self.i -= 1
      self.loadCurrentFrame()
      self.preloadThumbs()
    }
  }

  @IBAction func left() {
    if( self.j > 0 ) {
      self.j -= 1
      self.loadCurrentFrame()
      self.preloadThumbs()
    }
  }
  
  @IBAction func right() {
    if( self.j < UInt8(ImageManager.sharedInstance.gridSize) - 1 ) {
      self.j += 1
      self.loadCurrentFrame()
      self.preloadThumbs()
    }
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
      self.loadCurrentFrame()
    }
    
  }
  
  private func loadCurrentFrame() {
    ImageManager.sharedInstance.loadImage(self.i, j: self.j) {
      (image: UIImage) in
      
      self.imageView?.image = image
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
      self.i = 0
      self.j = UInt8(ImageManager.sharedInstance.gridSize / 2)
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
  
  @IBAction func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
    if( gestureRecognizer.state == .Changed ) {
      let velocity = gestureRecognizer.velocityInView(self.view)
      let projectedDate : NSDate = self.lastUpdateTime.dateByAddingTimeInterval(0.1)
      let now : NSDate = NSDate.init()
      if( projectedDate.compare(now) == .OrderedAscending ) {
        if( Float(velocity.x) > self.panThreshold ) {
          self.lastUpdateTime = NSDate.init()
          self.left()
        }
        else if( Float(velocity.x) < -self.panThreshold ) {
          self.lastUpdateTime = NSDate.init()
          self.right()
        }
        else if( Float(velocity.y) > self.panThreshold ) {
          self.lastUpdateTime = NSDate.init()
          self.down()
        }
        else if( Float(velocity.y) < -self.panThreshold ) {
          self.lastUpdateTime = NSDate.init()
          self.up()
        }
      }
    }
  }
}

