//
//  Photo.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/11/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import Foundation
import CoreData

@objc(Photo)

class Photo: NSManagedObject, Printable {

    struct Keys {
        static let Title = "title"
        static let URLString = "url_m"
    }
    static let entityName = "Photo"


    @NSManaged var title: String
    @NSManaged var urlString: String
    @NSManaged var location: Pin

    override var description: String { return title + " " + location.description }

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    init(dictionary: [String : AnyObject], pin: Pin, context: NSManagedObjectContext) {
        println("Photo init thread:\(NSThread.currentThread().description)")
        let entity =  NSEntityDescription.entityForName(Photo.entityName, inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        println("Photo init pin:\(pin.description)")
        title = dictionary[Keys.Title] as! String
        urlString = dictionary[Keys.URLString] as! String
        self.location = pin
    }


    
}