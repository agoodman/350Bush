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
  
  let panThreshold : Float = 20
  let spaceThreshold : Float = 10
  let timeThreshold : Float = 50
  let fullResolutionDelay: NSTimeInterval = 0.25
  
  @IBOutlet var imageView: UIImageView?
  @IBOutlet var horizontalSlider: UISlider?
  @IBOutlet var verticalSlider: UISlider?
  
  @IBOutlet var horizontalOverlay: UIView?
  @IBOutlet var verticalOverlay: UIView?
  private var hasDisplayedHorizontalOverlay: Bool = false
  private var hasDisplayedVerticalOverlay: Bool = false
  private var hasNavigatedHorizontally: Bool = false
  private var hasNavigatedVertically: Bool = false
  
  var i: UInt8 = 0
  var j: UInt8 = 0
  var lastUpdateTime: NSDate = NSDate()
  var iActive: Bool = false
  var jActive: Bool = false
  var timer: NSTimer?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.horizontalSlider?.continuous = false
    self.horizontalSlider?.hidden = true
    self.verticalSlider?.continuous = false
    self.verticalSlider?.hidden = true
    
    self.horizontalOverlay?.hidden = true
    self.verticalOverlay?.hidden = true
        
    // create pan gesture recognizer to track touches
    let recognizer : UIPanGestureRecognizer = UIPanGestureRecognizer.init(target: self, action: #selector(handlePan))
    self.view.addGestureRecognizer(recognizer)
    
    ImageManager.sharedInstance.fetchManifest() {
      [weak self] (success: Bool) in
      
      if( !success ) {
        NSLog("ImageManager.fetchManifest FAIL")
        return
      }
      
      NSLog("ImageManager.fetchManifest OK")
      self!.loadManifestContents()
    }
  }
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)

    if( !self.hasDisplayedHorizontalOverlay ) {
      self.horizontalOverlay?.hidden = false
      self.hasDisplayedHorizontalOverlay = true
    }
    else if( !self.hasDisplayedVerticalOverlay ) {
      self.verticalOverlay?.hidden = false
      self.hasDisplayedVerticalOverlay = true
    }
  }
  
  @IBAction func up() {
    if( self.hasDisplayedVerticalOverlay ) {
      self.hasNavigatedVertically = true
      self.refreshOverlays()
    }
    
    if( self.i < UInt8(ImageManager.sharedInstance.gridSize) - 1 ) {
      NSLog("ImageManager.up")
      self.i += 1
      self.loadCurrentThumb()
      self.preloadThumbs()
    }
  }
  
  @IBAction func down() {
    if( self.hasDisplayedVerticalOverlay ) {
      self.hasNavigatedVertically = true
      self.refreshOverlays()
    }

    if( self.i > 0 ) {
      NSLog("ImageManager.down")
      self.i -= 1
      self.loadCurrentThumb()
      self.preloadThumbs()
    }
  }

  @IBAction func left() {
    if( self.hasDisplayedHorizontalOverlay ) {
      self.hasNavigatedHorizontally = true
      self.refreshOverlays()
    }

    if( self.j > 0 ) {
      NSLog("ImageManager.left")
      self.j -= 1
      self.loadCurrentThumb()
      self.preloadThumbs()
    }
  }
  
  @IBAction func right() {
    if( self.hasDisplayedHorizontalOverlay ) {
      self.hasNavigatedHorizontally = true
      self.refreshOverlays()
    }

    if( self.j < UInt8(ImageManager.sharedInstance.gridSize) - 1 ) {
      NSLog("ImageManager.right")
      self.j += 1
      self.loadCurrentThumb()
      self.preloadThumbs()
    }
  }
  
  @IBAction func showAboutView() {
    self.performSegueWithIdentifier("ShowAbout", sender: self)
  }
  
  private func preloadThumbs() {
  
    let iDelta : UInt8 = (self.iActive ? ImageManager.sharedInstance.delta : 1)
    let jDelta : UInt8 = (self.jActive ? ImageManager.sharedInstance.delta : 1)
    let iRange : Range = createRange(self.i, delta: iDelta)
    let jRange : Range = createRange(self.j, delta: jDelta)
    ImageManager.sharedInstance.fetchRange(iRange, jRange: jRange, quality: .Thumb, progress: {
      [weak self] (complete: UInt, total: UInt) in
      
//      NSLog("progress: %d of %d", complete, total)
    }) {
      [weak self] (success: Bool) in
      
      self!.loadCurrentThumb()
    }
    
  }
  
  private func loadCurrentFrame(quality: Quality) {
    self.horizontalSlider?.setValue(Float(self.j), animated: false)
    self.verticalSlider?.setValue(Float(self.i), animated: false)
        
    ImageManager.sharedInstance.loadImage(self.i, j: self.j, quality: quality) {
      [weak self] (image: UIImage) in
      
      self!.imageView?.image = image
    }
  }

  private func loadCurrentThumb() {
    NSLog("Frame.loadThumb %d, %d", self.i, self.j)
    if( self.timer != nil ) {
      self.timer?.invalidate()
    }
    
    loadCurrentFrame(.Thumb)
    
    self.timer = NSTimer.scheduledTimerWithTimeInterval(fullResolutionDelay, target: self, selector: #selector(loadCurrentFull), userInfo: nil, repeats: false)
  }
  
  @objc private func loadCurrentFull() {
    NSLog("Frame.loadFull %d, %d", self.i, self.j)
    loadCurrentFrame(.Full)
  }
  
  private func loadManifestContents() {
    
    ImageManager.sharedInstance.loadManifest() {
      [weak self] (success: Bool) in
      
      if( !success ) {
        NSLog("ImageManager.loadManifest FAIL")
        return
      }
      
      NSLog("ImageManager.loadManifest OK (size: %d)", ImageManager.sharedInstance.gridSize)
      self!.i = 0
      self!.j = UInt8(ImageManager.sharedInstance.gridSize / 2)
      self!.horizontalSlider?.minimumValue = 0
      self!.horizontalSlider?.maximumValue = Float(ImageManager.sharedInstance.gridSize)
      self!.verticalSlider?.minimumValue = 0
      self!.verticalSlider?.maximumValue = Float(ImageManager.sharedInstance.gridSize)
      self!.preloadThumbs()
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
  
  private func refreshOverlays() {
    if( hasDisplayedVerticalOverlay && hasNavigatedVertically ) {
      dispatch_after(500, dispatch_get_main_queue()) {
        [unowned self] in
        self.verticalOverlay?.hidden = true
      }
    }
    else if( hasDisplayedHorizontalOverlay && hasNavigatedHorizontally ) {
      dispatch_after(500, dispatch_get_main_queue()) {
        [unowned self] in
        self.horizontalOverlay?.hidden = true
      }
    }
  }
  
  @IBAction func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
    if( gestureRecognizer.state == .Ended ) {
      self.iActive = false
      self.jActive = false
      self.horizontalSlider?.hidden = true
      self.verticalSlider?.hidden = true

      if( hasNavigatedHorizontally && !hasNavigatedVertically ) {
        dispatch_after(500, dispatch_get_main_queue()) {
          [weak self] in
          
          self!.verticalOverlay?.hidden = false
          self!.hasDisplayedVerticalOverlay = true
        }
      }
      
      self.refreshOverlays()
    }
    else if( gestureRecognizer.state == .Changed ) {
      let translation = gestureRecognizer.translationInView(self.view)
      let velocity = gestureRecognizer.velocityInView(self.view)
      let projectedDate : NSDate = self.lastUpdateTime.dateByAddingTimeInterval(0.1)
      let now : NSDate = NSDate.init()
      if( projectedDate.compare(now) == .OrderedAscending ) {
        if( !self.iActive && !self.jActive && gestureRecognizer.numberOfTouches() == 1 && (Float(translation.x) > self.panThreshold || Float(translation.x) < -self.panThreshold) ) {
          self.horizontalSlider?.hidden = false
          self.verticalSlider?.hidden = true
          self.iActive = true
          self.jActive = false
          self.lastUpdateTime = NSDate.init()
        }
        else if( !self.iActive && !self.jActive && gestureRecognizer.numberOfTouches() == 1 && (Float(translation.y) > self.panThreshold || Float(translation.y) < -self.panThreshold) ) {
          self.horizontalSlider?.hidden = true
          self.verticalSlider?.hidden = false
          self.iActive = false
          self.jActive = true
          self.lastUpdateTime = NSDate.init()
        }
        else if( self.iActive ) {
          if( Float(velocity.x) > self.spaceThreshold ) {
            left()
          }
          else if( Float(velocity.x) < -self.spaceThreshold ) {
            right()
          }
          self.lastUpdateTime = NSDate.init()
        }
        else if( self.jActive ) {
          if( Float(velocity.y) > self.timeThreshold ) {
            down()
          }
          else if( Float(velocity.y) < -self.timeThreshold ) {
            up()
          }
          self.lastUpdateTime = NSDate.init()
        }
      }
    }
  }
}

