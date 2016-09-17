//
//  FrameManager.swift
//  350Bush
//
//  Created by Aubrey Goodman on 9/9/16.
//  Copyright © 2016 Aubrey Goodman. All rights reserved.
//

import Foundation


@objc public protocol FrameManagerDelegate : class {
  
  func didSelectFrameAt(i: Int, j: Int)
  
}

public class FrameManager {

  var delegate: FrameManagerDelegate?

  private var i: Int = 0
  private var j: Int = 0

  func select(i: Int, j: Int) {
    self.i = i
    self.j = j
    self.delegate?.didSelectFrameAt(i, j: j)
  }
  
}

public class Frame {
  let i: Int
  let j: Int
  init(i: Int, j: Int) {
    self.i = i
    self.j = j
  }
}
