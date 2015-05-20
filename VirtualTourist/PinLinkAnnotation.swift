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


    func updateSubtitle() {

        let totalNumPhotos = pinRef.totalAvailablePhotos
        let numLoaded = pinRef.photos.count

        var s: String
        switch totalNumPhotos {
        case 0: s = "No photos found"
        case 1: s = "1 photo, tap to see"
        default: s = "\(numLoaded) loaded of \(totalNumPhotos) photos, tap to see"
        }
        self.subtitle = s
    }

 }
