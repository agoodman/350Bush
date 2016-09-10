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
    }
    
  }
  
}

