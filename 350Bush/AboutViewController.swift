//
//  AboutViewController.swift
//  350Bush
//
//  Created by Aubrey Goodman on 9/11/16.
//  Copyright © 2016 Aubrey Goodman. All rights reserved.
//

import Foundation
import UIKit


class AboutViewController : UIViewController {

  @IBOutlet var continueButton: UIButton?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    
  }
  
  @IBAction func onContinueButton() {
    self.dismissViewControllerAnimated(false) {
      NSLog("wat")
    }
  }
  
  @IBAction func onBlogButton() {
    UIApplication.sharedApplication().openURL(NSURL.init(string: "https://350bush.wordpress.com")!)
  }
  
}
