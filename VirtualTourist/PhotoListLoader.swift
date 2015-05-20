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
public typealias BatchPhotosLoadedClosure = () -> Void


class PhotoListLoader: NSObject {

    // MARK: - Properties
    var batchPhotosLoadedClosure: BatchPhotosLoadedClosure?
    var isLoadingPhotos = false


    private let DESIRED_PHOTOS_PER_PAGE = 21
    private let pinAnnotation: PinLinkAnnotation
    private let inRegion: MKCoordinateRegion
    private var kvoContext: UInt8 = 1   // required to be a var
    private var uiReportingClosure: UIReportingClosure?
    private var totalPhotos: Int = 0
    private var totalPages: Int = 0
    private var perPage: Int = 0
    private var currentPage: Int = 0
    private var _numPhotosToLoad: Int = 0


    var numPhotosToLoad: Int {
        get { return _numPhotosToLoad }
        set { /*    
            `   This mechanism exists to let the UI know when the queue is finished loading all
                photos in the batch.  I tried using KVO and NSOperationQueue.operationCount to
                signal this, but it was not reliable.
                */
            if newValue < 0 { return }
            _numPhotosToLoad = newValue
            if isLoadingPhotos && _numPhotosToLoad == 0 {
                isLoadingPhotos = false
                if batchPhotosLoadedClosure != nil { batchPhotosLoadedClosure!() }
                dispatch_async(dispatch_get_main_queue(), { self.pinAnnotation.updateSubtitle() })
            }
        }
    }

    private var privateQueueContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = CoreDataStackManager.sharedInstance.managedObjectContext
        return context
        }()


    // MARK: - Init

    init(forAnnotation: PinLinkAnnotation, inRegion: MKCoordinateRegion) {
        self.pinAnnotation = forAnnotation
        self.inRegion = inRegion
     }

    // MARK: - Loading chain

    func load(withUIClosure: UIReportingClosure, batchPhotosLoadedClosure: BatchPhotosLoadedClosure?) {
        var desiredPage = 1
        if (totalPages > 0) {
            // not the first time we have loaded, get the next page
            desiredPage = currentPage + 1
            if desiredPage > totalPages { desiredPage = 1 }
        }
        self.uiReportingClosure = withUIClosure
        self.batchPhotosLoadedClosure = batchPhotosLoadedClosure
        NetClient.sharedInstance.initPhotoListSearch(desiredPage, desiredPhotosPerPage: DESIRED_PHOTOS_PER_PAGE,
            region: inRegion, completionHandler: self.searchClosure)
    }


    func searchClosure(data: NSData!, response: NSURLResponse!, error: NSError?) -> Void {
        if error != nil {
            if uiReportingClosure != nil { uiReportingClosure!(annotation: pinAnnotation, error: error) }
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
        if uiReportingClosure != nil { uiReportingClosure!(annotation: pinAnnotation, error: reportError) }
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
        self.parsePhotoListArray(photosDictionary["photo"] as! [[String: AnyObject]])
    }


    private func parsePhotoListArray(photosArray: [[String: AnyObject]]) {
        //    println("parsePhotoListArray thread:\(NSThread.currentThread().description)")

        let photoLoadQueue = NSOperationQueue()

        var error: NSError? = nil
        let objectID = pinAnnotation.pinRef.objectID
        let privateQPin = privateQueueContext.existingObjectWithID(objectID, error: &error) as! Pin
        if error != nil {
            if uiReportingClosure != nil { uiReportingClosure!(annotation: pinAnnotation, error: error) }
            return
        }
        privateQPin.totalAvailablePhotos = self.totalPhotos

        //  println("photosArray:\(photosArray)")
        for aPhotoDictionary in photosArray {
            let photo = Photo(dictionary: aPhotoDictionary, pin: privateQPin, context: privateQueueContext)
        }

        // save both the private context and the parent main context
        self.privateQueueContext.save(&error)
        if error != nil {
            if uiReportingClosure != nil { uiReportingClosure!(annotation: pinAnnotation, error: error) }
            return
        }
        dispatch_async(dispatch_get_main_queue(), {
            CoreDataStackManager.sharedInstance.saveContext()
            self.pinAnnotation.updateSubtitle()
        })
        if privateQPin.photos.count == 0 { return }


        // download all photos from the list, max 1 at a time (got Resource Busy Error when I tried 2 or 3)
        photoLoadQueue.maxConcurrentOperationCount = 1
        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: nil, delegateQueue: photoLoadQueue)


        var loaders = [PhotoLoader]()
        privateQueueContext.performBlockAndWait({
            for photo in privateQPin.photos {
                if photo.urlString == "" { continue }
                loaders.append(PhotoLoader(photo: photo, privateQueueContext: self.privateQueueContext, listLoader: self))
            }
        })
        isLoadingPhotos = true
        numPhotosToLoad = loaders.count
        privateQueueContext.performBlock({ for loader in loaders { loader.load(session) } })
     }
    



}





