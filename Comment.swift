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

    // MARK: - Properties
    struct Keys {
        static let AuthorName = "authorname"
        static let DateCreated = "datecreate"
        static let Content = "_content"
    }
    static let entityName = "Comment"

    @NSManaged var photo: Photo?
    @NSManaged var authorName: String
    @NSManaged var dateCreated: NSDate
    @NSManaged var content: String

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

    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
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
            dateCreated = NSDate(timeIntervalSince1970: 0)
        }
    }


    func getDateAsString() -> String {
        println(".....date:\(self.dateCreated)")
        return dateFormatter.stringFromDate(dateCreated)
    }

}

/*


{ "id": "335003-14950215319-72157646965665487",
"author": "126854276@N02", 
"authorname": "myeshs_hall", 
"iconserver": "2945", 
"iconfarm": 3, 
"datecreate": "1410200806", 
"permalink": "https:\/\/www.flickr.com\/photos\/jorgeq82\/14950215319\/#comment72157646965665487", 
"path_alias": "", 
"realname": "", 
"_content": "that looks so much fun there" },

*/