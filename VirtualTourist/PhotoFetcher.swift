//
//  PhotoFetcher
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/10/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import UIKit
import CoreData

class PhotoFetcher {

    static let NOTIFICATION_PHOTO_FETCHED = "com.o2l.photofetched"

    private let photo: Photo
    private let privateQueueContext: NSManagedObjectContext
    private let listFetcher: PhotoListFetcher

    init(photo: Photo, privateQueueContext: NSManagedObjectContext, listFetcher: PhotoListFetcher) {
        self.privateQueueContext = privateQueueContext
        self.photo = photo
        self.listFetcher = listFetcher
    }

    func fetchPhotoFromFlickr(session: NSURLSession) {
        NetClient.sharedInstance.getOneFlickrPhoto(photo.urlString, session: session,
            completionHandler: loadingClosure)
    }

    func loadingClosure(data: NSData!, response: NSURLResponse!, error: NSError?) -> Void {
        var image: UIImage?
        if error != nil {
            // Sometimes I get a whole bunch of Resource Busy Errors (NSPOSIXErrorDomain Code=16)
            // I don't want to annoy the user with a series of alerts, so show a failure image
            image = UIImage(named: "FailedImage")
        } else {
            image = UIImage(data: data)
        }

        privateQueueContext.performBlockAndWait({
            self.photo.photoImage = image
            var error: NSError? = nil
            self.privateQueueContext.save(&error)
            if error != nil {
                NSLog("PhotoLoader saving error \(error), \(error!.userInfo)")
                return
            }
        })
        listFetcher.numPhotosToFetch--
        dispatch_async(dispatch_get_main_queue(), {
            CoreDataStackManager.sharedInstance.saveContext()
            NSNotificationCenter.defaultCenter().postNotificationName(PhotoFetcher.NOTIFICATION_PHOTO_FETCHED, object: nil)
        })

    }


}