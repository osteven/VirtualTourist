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

    // MARK: - Properties
    private let photo: Photo
    private var batchCommentsLoadedClosure: BatchCommentsLoadedClosure?
    private var uiReportingClosure: UIReportingClosure?
    private var privateQueueContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = CoreDataStackManager.sharedInstance.managedObjectContext
        return context
        }()
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext!
    }



    // MARK: - Init
    init(photo: Photo) { self.photo = photo }


    // MARK: - Loading Chain
    func fetchFlickrCommentList(withUIClosure: UIReportingClosure?, batchCommentsLoadedClosure: BatchCommentsLoadedClosure) {
        self.batchCommentsLoadedClosure = batchCommentsLoadedClosure
        self.uiReportingClosure = withUIClosure

        // if it was a previously loaded photo, the comments will already be saved in the DB
        loadCommentDataFromDB(photo)
        if photo.comments.count == 0 {
            // if not in the DB, look for comments from the Flickr API
            NetClient.sharedInstance.initFlickrCommentSearch(photo.id,
                completionHandler: self.searchClosure)
        }
    }

    func searchClosure(data: NSData!, response: NSURLResponse!, error: NSError?) -> Void {
        if error != nil { reportError(error); return }

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
                    if error != nil { self.reportError(error); return }
                })
                assert(pqPhoto != nil)

                var addedComments = [Comment]()
                for jsonComment in commentArray {
                    self.privateQueueContext.performBlockAndWait({
                        let comment = Comment(dictionary: jsonComment, photo: pqPhoto!, context: self.privateQueueContext)
                        addedComments.append(comment)
                    })
                 }
                // save both the private context and the parent main context
                self.privateQueueContext.performBlockAndWait({
                    var saveError: NSError? = nil
                    self.privateQueueContext.save(&saveError)
                    if saveError != nil { self.reportError(saveError); return }
               })
                dispatch_async(dispatch_get_main_queue(), {
                    CoreDataStackManager.sharedInstance.saveContext()
                    self.loadCommentDataFromDB(self.photo)
                    if self.batchCommentsLoadedClosure != nil { self.batchCommentsLoadedClosure!() }
                })
            }
        }
    }
    
    // MARK: - Utility
    private func reportError(error: NSError?) {
        if error == nil { return }
        if uiReportingClosure != nil {
            uiReportingClosure!(error: error)
        } else {
            NSLog("Error in Comments:\(error), \(error!.userInfo)")
        }
    }


    // MARK: - Database Fetch
    func loadCommentDataFromDB(photo: Photo) {
        var error: NSError? = nil
        let fetchRequest = NSFetchRequest(entityName: "Comment")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "photoID == %@", photo.id);
        let results = self.sharedContext.executeFetchRequest(fetchRequest, error: &error)
        if error != nil { reportError(error); return }
        for comment in results! {
            photo.comments.append(comment as! Comment)
        }
    }


}