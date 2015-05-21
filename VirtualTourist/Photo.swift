//
//  Photo.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/11/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//
// A flickr image ID is globally unique:
// https://code.flickr.net/2010/02/08/ticket-servers-distributed-unique-primary-keys-on-the-cheap/

import UIKit
import CoreData

@objc(Photo)

class Photo: NSManagedObject, Printable {

    // MARK: - Properties
    struct Keys {
        static let Title = "title"
        static let URLString = "url_m"
        static let ID = "id"
    }
    static let entityName = "Photo"

    @NSManaged var id: String
    @NSManaged var title: String
    @NSManaged var urlString: String
    @NSManaged var location: Pin
    @NSManaged var filePath: String?
    // I manually manage the comment relationship, see notes in Comment.swift
    var comments = [Comment]()


    override var description: String {
        return id + ":" + fileName + ":" + title
    }

    var photoImage: UIImage? {
        get { return ImageCache.sharedInstance.imageWithIdentifier(fileName) }
        set { filePath = ImageCache.sharedInstance.storeImage(newValue, withIdentifier: fileName) }
    }

    private var fileName: String {
        return location.uuid + "/" + (urlString as NSString).lastPathComponent
    }



    // MARK: - Init
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    init(dictionary: [String : AnyObject], pin: Pin, context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName(Photo.entityName, inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        if let title = dictionary[Keys.Title] as? String {
            self.title = title
        } else {
            self.title = ""
        }
        if let urlString = dictionary[Keys.URLString] as? String {
            self.urlString = urlString
        } else {
            self.urlString = ""
        }
        if let id = dictionary[Keys.ID] as? String {
            self.id = id
        } else {
            self.id = ""
        }
        self.location = pin
        self.filePath = nil
    }


    // MARK: - Delete Comments

    func deleteComments(sharedContext: NSManagedObjectContext) {
        for comment in comments {
            sharedContext.deleteObject(comment)
        }
    }


    
}