//
//  Pin.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/7/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//
/*
http://www.andrewcbancroft.com/2014/07/17/implement-nsmanagedobject-subclass-in-swift/
http://www.andrewcbancroft.com/2015/02/18/core-data-cheat-sheet-for-swift-ios-developers/
*/

import Foundation
import MapKit
import CoreData

@objc(Pin)

class Pin: NSManagedObject, Printable {

    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
        static let LocationName = "locationName"
        static let Photos = "photos"
    }
    static let entityName = "Pin"


    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var locationName: String
    @NSManaged var photos: [Photo]

    override var description: String { return locationName + ":\(photos.count) photos" }
    var locationCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }


    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        println("context=\(context.description)\n\(context.userInfo)")
        if let entity =  NSEntityDescription.entityForName(Pin.entityName, inManagedObjectContext: context) {
            super.init(entity: entity,insertIntoManagedObjectContext: context)

            latitude = dictionary[Keys.Latitude] as! Double
            longitude = dictionary[Keys.Longitude] as! Double
            locationName = dictionary[Keys.LocationName] as! String
        } else {
            println("entity is nil for \(Pin.entityName)")
            abort()
        }
    }




}