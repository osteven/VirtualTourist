//
//  Comment.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/18/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import CoreData

@objc(Comment)

class Comment: NSManagedObject, Printable {
    /*
    Note: I tried for several days to get Photo to be in a one-to-many relationship with Comment.  I
    could not get it to work  I was able to save the comments and the related photo.  But anytime I 
    tried to access a photo.comments, it would crash:
    2015-05-20 12:19:13.351 VirtualTourist[19199:7108689] -[__NSCFSet objectAtIndex:]: unrecognized selector sent to instance 0x7fc6db541e20
    2015-05-20 12:19:13.357 VirtualTourist[19199:7108689] *** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[__NSCFSet objectAtIndex:]: unrecognized selector sent to instance 0x7fc6db541e20'

    Rather than spend any more time debugging, I am manully managing the relationship.  The comment holds a 
    photoID as a foreign key.  The CommentListLoader tries to fetch all comments with a matching photoID.  
    If it doesn't find any, it queries the Flickr API.  If it finds some there, it saves Comment objects 
    with the appropriate photoID.

    */




    // MARK: - Properties
    struct Keys {
        static let AuthorName = "authorname"
        static let DateCreated = "datecreate"
        static let Content = "_content"
    }
    static let entityName = "Comment"

    var photo: Photo?
    @NSManaged var authorName: String
    @NSManaged var dateCreated: NSDate?
    @NSManaged var content: String
    @NSManaged var photoID: String

    override var description: String {
        return content
    }

    private let dateFormatter: NSDateFormatter = {
        let df = NSDateFormatter()
        df.dateFormat = "EEE, MMM d, yyyy - h:mm a"
        return df
    }()

    // MARK: - Init
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    init(dictionary: [String : AnyObject], photo: Photo, context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName(Comment.entityName, inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        if let authorName = dictionary[Keys.AuthorName] as? String {
            self.authorName = authorName
        } else {
            self.authorName = ""
        }
        if let content = dictionary[Keys.Content] as? String {
            self.content = content
        } else {
            self.content = ""
        }
        if let numStr = dictionary[Keys.DateCreated] as? String {
            let timeInterval = NSTimeInterval((numStr as NSString).doubleValue)
            dateCreated = NSDate(timeIntervalSince1970: timeInterval)
        } else {
            dateCreated = nil
        }
        self.photo = photo
        photoID = photo.id
    }


    func getDateAsString() -> String {
        if dateCreated == nil { return "" }
        return dateFormatter.stringFromDate(dateCreated!)
    }

}

