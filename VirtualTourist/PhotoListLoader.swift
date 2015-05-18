//
//  PhotoListLoader.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/14/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import Foundation
import CoreData
import MapKit


public typealias UIReportingClosure = (annotation: MKPointAnnotation, error: NSError?) -> Void


class PhotoListLoader {

    // MARK: - Properties
    private let pinAnnotation: PinLinkAnnotation
    private var totalPhotos: Int = 0
    private let uiReportingClosure: UIReportingClosure
    private var totalPages: Int = 0
    private var perPage: Int = 0
    private var currentPage: Int = 0

    let photoLoadQueue = NSOperationQueue()


    class func numPhotosString(num: Int) -> String {
        switch num {
        case 0: return "No photos found"
        case 1: return "1 photo, tap to see"
        default: return "\(num) photos, tap to see"
        }
    }

    var privateQueueContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = CoreDataStackManager.sharedInstance.managedObjectContext
        return context
        }()




    init(forAnnotation: PinLinkAnnotation, inRegion: MKCoordinateRegion, withUIClosure: UIReportingClosure) {
        self.pinAnnotation = forAnnotation
        self.uiReportingClosure = withUIClosure
        NetClient.sharedInstance.initPhotoListSearch(inRegion, completionHandler: self.searchClosure)
    }


    func searchClosure(data: NSData!, response: NSURLResponse!, error: NSError?) -> Void {
        //println("searchClosure thread:\(NSThread.currentThread().description)")
        if error != nil {
            uiReportingClosure(annotation: pinAnnotation, error: error)
            return
        }

        var parsingError: NSError? = nil
        let parsedResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments,
            error: &parsingError) as! NSDictionary
        if parsingError == nil {
            if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                // this closure runs in a background thread, so I have to access the data on a private queue
                self.privateQueueContext.performBlock( { self.gotNetResponse(photosDictionary) })
                return
            }
        }
        let dict = NSMutableDictionary()
        dict[NSLocalizedDescriptionKey] = "Failed to find photo dictionary in JSON response"
        if parsingError != nil { dict[NSUnderlyingErrorKey] = parsingError }
        let reportError = NSError(domain: "com.o2l.error.json", code: 9999, userInfo: dict as [NSObject : AnyObject])
        uiReportingClosure(annotation: pinAnnotation, error: reportError)
    }


    private func gotNetResponse(photosDictionary: [String:AnyObject]) {
        //println("gotNetResponse thread:\(NSThread.currentThread().description)")
        if let totalPages = photosDictionary["pages"] as? Int {
            self.totalPages = totalPages
         }
        if let perPage = photosDictionary["perpage"] as? Int {
            self.perPage = perPage
        }
        // I don't know why this one can only be read as a string?
        if let totalPhotoString = photosDictionary["total"] as? String {
            self.totalPhotos = (totalPhotoString as NSString).integerValue
        }
        if let page = photosDictionary["page"] as? Int {
            self.currentPage = page
        }
        dispatch_async(dispatch_get_main_queue(), {
            self.pinAnnotation.subtitle = PhotoListLoader.numPhotosString(self.totalPhotos)
        })
        self.parsePhotoListArray(photosDictionary["photo"] as! [[String: AnyObject]])
    }


    private func parsePhotoListArray(photosArray: [[String: AnyObject]]) {
        // println("parsePhotoListArray thread:\(NSThread.currentThread().description)")

        var error: NSError? = nil
        let objectID = pinAnnotation.pinRef.objectID
        let privateQPin = privateQueueContext.existingObjectWithID(objectID, error: &error) as! Pin
        if error != nil {
            uiReportingClosure(annotation: pinAnnotation, error: error)
            return
        }

        for aPhotoDictionary in photosArray {
            let photo = Photo(dictionary: aPhotoDictionary, pin: privateQPin, context: privateQueueContext)
        }

        // save both the private context and the parent main context
        self.privateQueueContext.save(&error)
        if error != nil {
            uiReportingClosure(annotation: pinAnnotation, error: error)
            return
        }
        dispatch_async(dispatch_get_main_queue(), { CoreDataStackManager.sharedInstance.saveContext() })
        if privateQPin.photos.count == 0 { return }


        // download all photos from the list, max 3 at a time
        photoLoadQueue.maxConcurrentOperationCount = 3
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: nil, delegateQueue: photoLoadQueue)


        for photo in privateQPin.photos {
            if photo.urlString == "" { continue }
            privateQueueContext.performBlock({
                let loader = PhotoLoader(photo: photo, privateQueueContext: self.privateQueueContext, session: session)
            })

            // uncomment this line to test the asynchronous display of photos in the PhotoAlbumViewController
            // if (i++ % 5 == 0) {privateQueueContext.performBlockAndWait({ NSThread.sleepForTimeInterval(0.7)})}
        }
     }
    





}
