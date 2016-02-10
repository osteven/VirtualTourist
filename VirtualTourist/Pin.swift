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

class Pin: NSManagedObject {

    // MARK: - Properties
    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
        static let LocationName = "locationName"
        static let Photos = "photos"
        static let TotalAvailablePhotos = "totalAvailablePhotos"
    }
    static let entityName = "Pin"


    @NSManaged var totalAvailablePhotos: Int32
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var locationName: String
    @NSManaged var uuid: String
    @NSManaged var photos: [Photo]

    var photoListFetcher: PhotoListFetcher?


    override var description: String { return locationName + ":\(photos.count) photos" }
    var locationCoordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }


    // MARK: - Init
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName(Pin.entityName, inManagedObjectContext: context)
        super.init(entity: entity!, insertIntoManagedObjectContext: context)

        if let latitude = dictionary[Keys.Latitude] as? Double {
            self.latitude = latitude
        } else {
            self.latitude = 0.0
        }
        if let longitude = dictionary[Keys.Longitude] as? Double {
            self.longitude = longitude
        } else {
            self.longitude = 0.0
        }
        if let locationName = dictionary[Keys.LocationName] as? String {
            self.locationName = locationName
        } else {
            self.locationName = ""
        }
        uuid = NSUUID().UUIDString
        totalAvailablePhotos = 0
        ImageCache.sharedInstance.createStorageDirectory(uuid)
    }

    // MARK: - Delete
    func deleteAllPhotos(context: NSManagedObjectContext) {
        for photo in photos {
            photo.deleteComments(context)
            photo.photoImage = nil          // the cache deletes the disk file
            context.deleteObject(photo)
        }
    }


}