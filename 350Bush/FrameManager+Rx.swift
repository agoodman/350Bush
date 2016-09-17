//
//  FrameManager+Rx.swift
//  350Bush
//
//  Created by Aubrey Goodman on 9/17/16.
//  Copyright © 2016 Aubrey Goodman. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

  
extension FrameManager {
  /**
   Factory method that enables subclasses to implement their own `delegate`.
   - returns: Instance of delegate proxy that wraps `delegate`.
   */
  public func createRxDelegateProxy() -> RxFrameManagerDelegateProxy {
    return RxFrameManagerDelegateProxy(parentObject: self)
  }
  
}


public extension FrameManager {
  
  /**
   Reactive wrapper for `delegate`.
   
   For more information take a look at `DelegateProxyType` protocol documentation.
   */
  public var rx_delegate: DelegateProxy {
    return RxFrameManagerDelegateProxy.proxyForObject(self)
  }
  
  /**
   Reactive wrapper for `text` property.
   */
  public var rx_currentFrame: Observable<Frame> {
    return rx_delegate.observe(#selector(FrameManagerDelegate.didSelectFrameAt(_:j:)))
      .map {
        frame in
        
        guard let result = frame as? Frame else {
          throw RxCocoaError.CastingError(object: frame, targetType: Frame.self)
        }
        
        return result
      }
  }
  
//  public var text: ControlProperty<String> {
//    let source: Observable<String> = Observable.deferred { [weak searchBar = self.base as UISearchBar] () -> Observable<String> in
//      let text = searchBar?.text ?? ""
//      
//      return (searchBar?.rx.delegate.observe(#selector(UISearchBarDelegate.searchBar(_:textDidChange:))) ?? Observable.empty())
//        .map { a in
//          return a[1] as? String ?? ""
//        }
//        .startWith(text)
//    }
//    
//    let bindingObserver = UIBindingObserver(UIElement: self.base) { (searchBar, text: String) in
//      searchBar.text = text
//    }
//    
//    return ControlProperty(values: source, valueSink: bindingObserver)
//  }
//  
  
}
