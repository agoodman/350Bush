//
//  StringExtensions.swift
//  350Bush
//
//  Created by Aubrey Goodman on 9/9/16.
//  Copyright © 2016 Aubrey Goodman. All rights reserved.
//

extension Character {
  
  func UTF8() -> UInt8 {
    for s in String(self).utf8 {
      return s
    }
    return 0
  }
  
}
