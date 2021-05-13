//
//  corenavigation.swift
//  navigation
//
//  Created by User on 5/11/21.
//

import Foundation
import MapboxCoreNavigation

@objc(UhSpotNavigationManager)
class UhSpotNavigationManager: RCTViewManager {
  override func view() -> UIView! {
     return UhSpotNavigationView();
   }
  
  @objc func addEvent(name: String, location: String, date: NSNumber) -> Void {
    
  }
}
