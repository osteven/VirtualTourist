//
//  PhotoLoader.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/10/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import UIKit
import CoreData

class PhotoLoader {

    static let NOTIFICATION_PHOTO_LOADED = "com.o2l.photoloaded"

    private let photo: Photo
    private let privateQueueContext: NSManagedObjectContext
    private var currentSession: NSURLSession?
    private var retryCount = 0
    private let listLoader: PhotoListLoader

    init(photo: Photo, privateQueueContext: NSManagedObjectContext, listLoader: PhotoListLoader) {
        self.privateQueueContext = privateQueueContext
        self.photo = photo
        self.listLoader = listLoader
    }

    func load(session: NSURLSession) {
        self.currentSession = session
        NetClient.sharedInstance.getOnePhotoImage(photo.urlString, session: session, completionHandler: loadingClosure)
    }

    func loadingClosure(data: NSData!, response: NSURLResponse!, error: NSError?) -> Void {
        var image: UIImage?
        if error != nil {
            // sometimes I get a Resource Busy Error.
            println("PhotoLoader closure error: \(error)")
            image = UIImage(named: "FailedImage")

        } else {
            image = UIImage(data: data)
        }

        privateQueueContext.performBlockAndWait({
            self.photo.photoImage = image
            var error: NSError? = nil
            self.privateQueueContext.save(&error)
            if error != nil {
                println("PhotoLoader saving error=\(error)")
                return
            }
        })
        listLoader.numPhotosToLoad--
        dispatch_async(dispatch_get_main_queue(), {
            CoreDataStackManager.sharedInstance.saveContext()
            NSNotificationCenter.defaultCenter().postNotificationName(PhotoLoader.NOTIFICATION_PHOTO_LOADED, object: nil)
        })

    }


}