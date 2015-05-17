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


    init(photo: Photo, privateQueueContext: NSManagedObjectContext, session: NSURLSession) {
        //    println("PhotoLoader init thread:\(NSThread.currentThread().description)")
        self.privateQueueContext = privateQueueContext
        self.photo = photo
        NetClient.sharedInstance.getOnePhotoImage(photo.urlString, session: session, completionHandler: loadingClosure)
    }


    func loadingClosure(data: NSData!, response: NSURLResponse!, error: NSError?) -> Void {
        //println("\n\n\nloadingClosure thread:\(NSThread.currentThread().description)")
        if error != nil {
            println("PhotoLoader closure error=\(error)")
            return
        }

        let image = UIImage(data: data)
        privateQueueContext.performBlockAndWait({
            self.photo.photoImage = image
            // println("PhotoLoader path=\(self.photo.filePath), file=\(self.photo.fileName)")
            var error: NSError? = nil
            self.privateQueueContext.save(&error)
            if error != nil {
                println("PhotoLoader saving error=\(error)")
                return
            }
        })
        dispatch_async(dispatch_get_main_queue(), {
            CoreDataStackManager.sharedInstance.saveContext()
            NSNotificationCenter.defaultCenter().postNotificationName(PhotoLoader.NOTIFICATION_PHOTO_LOADED, object: nil)
        })

    }


}