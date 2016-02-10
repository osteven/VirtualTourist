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

    func searchClosure(data: NSData?, response: NSURLResponse?, error: NSError?) -> Void {
        if error != nil || data == nil { reportError(error); return }

        let parsedDict: NSDictionary?
        do {
            try parsedDict = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments) as? NSDictionary
        } catch let parseError as NSError {
            reportError(parseError)
            return
        }
        guard let commentsDictionary = parsedDict?.valueForKey("comments") as? [String:AnyObject],
            commentArray = commentsDictionary["comment"] as? [[String: AnyObject]] else { return }

        var pqPhoto: Photo?
        self.privateQueueContext.performBlockAndWait({
            do {
                pqPhoto = try self.privateQueueContext.existingObjectWithID(self.photo.objectID) as? Photo
            } catch let error as NSError {
                self.reportError(error)
                return
            }
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
            do {
                try self.privateQueueContext.save()
            } catch let error as NSError {
                self.reportError(error)
                return
            }
        })
        dispatch_async(dispatch_get_main_queue(), {
            CoreDataStackManager.sharedInstance.saveContext()
            self.loadCommentDataFromDB(self.photo)
            if self.batchCommentsLoadedClosure != nil { self.batchCommentsLoadedClosure!() }
        })
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
        let fetchRequest = NSFetchRequest(entityName: "Comment")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dateCreated", ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "photoID == %@", photo.id);
        let results: [AnyObject]
        do {
            results = try self.sharedContext.executeFetchRequest(fetchRequest)
        } catch let error as NSError {
            self.reportError(error)
            return
        }
        guard let comments = results as? [Comment] else { return }
        for comment in comments {
            photo.comments.append(comment)
        }
    }


}