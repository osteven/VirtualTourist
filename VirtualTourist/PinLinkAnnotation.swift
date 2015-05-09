//
//  PinLinkAnnotation.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/7/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import MapKit


class PinLinkAnnotation: MKPointAnnotation, Printable {

    let pinRef: Pin
    override var description: String { return "PinLinkAnnotation for pin:\(pinRef.description)" }

    init(pinRef: Pin) {
        self.pinRef = pinRef
        super.init()
    }
 }
