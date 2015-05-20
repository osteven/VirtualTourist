//
//  CommentListLoader.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/19/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//
import CoreData


public typealias BatchCommentsLoadedClosure = () -> Void


class CommentListLoader {

    private let photo: Photo
    private var batchCommentsLoadedClosure: BatchCommentsLoadedClosure?
    private var privateQueueContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = CoreDataStackManager.sharedInstance.managedObjectContext
        return context
        }()



    init(photo: Photo) { self.photo = photo }

    func load(batchCommentsLoadedClosure: BatchCommentsLoadedClosure) {
        self.batchCommentsLoadedClosure = batchCommentsLoadedClosure
        NetClient.sharedInstance.initCommentSearch(photo.id, completionHandler: self.searchClosure)
    }

    func searchClosure(data: NSData!, response: NSURLResponse!, error: NSError?) -> Void {
        if error != nil {
            println("Comments error=\(error)")
            return
        }

        var parsingError: NSError? = nil
        let parsedResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments,
            error: &parsingError) as! NSDictionary
        if parsingError != nil { return }

        if let commentsDictionary = parsedResult.valueForKey("comments") as? [String:AnyObject] {
            if let commentArray = commentsDictionary["comment"] as? [[String: AnyObject]] {

                var pqPhoto: Photo? = nil
                self.privateQueueContext.performBlockAndWait({
                    var error: NSError? = nil
                    pqPhoto = self.privateQueueContext.existingObjectWithID(self.photo.objectID, error: &error) as? Photo
                    if error != nil { println("privateQueuePhoto Error=\(error)") }
                })
                if pqPhoto == nil { println("nil pqPhoto !!!!!") }

                 for jsonComment in commentArray {
                    self.privateQueueContext.performBlockAndWait({
                        let comment = Comment(dictionary: jsonComment, context: self.privateQueueContext)
                        comment.photo = pqPhoto
                        println("got Comment=\(comment)")
                    })
                 }
                // save both the private context and the parent main context
                self.privateQueueContext.performBlockAndWait({
                    var saveError: NSError? = nil
                    println("saving \(__FUNCTION__) in \(__FILE__.lastPathComponent.stringByDeletingPathExtension), \(NSThread.currentThread().description)")
                    self.privateQueueContext.save(&saveError)
                     if saveError != nil {
                        println("privateQueueContext save error=\(saveError)")
                        return
                    }
                    println("private saved comments=\(pqPhoto!.comments)")
               })
                dispatch_async(dispatch_get_main_queue(), {
                    println("saving main \(__FUNCTION__) in \(__FILE__.lastPathComponent.stringByDeletingPathExtension), \(NSThread.currentThread().description)")
                    CoreDataStackManager.sharedInstance.saveContext()
                    println("main saved comments=\(self.photo.comments)")
                   if self.batchCommentsLoadedClosure != nil { self.batchCommentsLoadedClosure!() }
                })
            }
        }
    }
    
    


}