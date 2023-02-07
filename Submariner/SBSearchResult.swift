//
//  SBSearchResult.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc class SBSearchResult: NSObject {
    @objc let tracks = NSMutableArray() // would be nice to be typesafe
    @objc let query: String // NSString
    
    @objc(initWithQuery:) init(query: String) {
        self.query = query
        super.init()
    }
}
