//
//  PhotoLoader.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/10/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import Foundation
import CoreData
import MapKit


public typealias UIReportingClosure = (error: NSError?) -> Void


class PhotoLoader {

    private let pinAnnotation: PinLinkAnnotation
    private var totalPhotos: Int = 0
    private let workingContext: NSManagedObjectContext
    private let uiReportingClosure: UIReportingClosure
    private var totalPages: Int = 0
    private var perPage: Int = 0
    private var currentPage: Int = 0


    class func numPhotosString(num: Int) -> String {
        switch num {
        case 0: return "No photos found"
        case 1: return "1 photo, tap to see"
        default: return "\(num) photos, tap to see"
        }
    }


    // NSFetchedResultsController

    init(forAnnotation: PinLinkAnnotation, inRegion: MKCoordinateRegion, withUIClosure: UIReportingClosure, context: NSManagedObjectContext) {
        println("PhotoLoader init thread:\(NSThread.currentThread().description)")
        self.pinAnnotation = forAnnotation
        self.workingContext = context
        self.uiReportingClosure = withUIClosure

        NetClient.sharedInstance.initFlickrSearch(inRegion, completionHandler: self.searchClosure)

    }


    func searchClosure(data: NSData!, response: NSURLResponse!, error: NSError?) -> Void {
        println("searchClosure thread:\(NSThread.currentThread().description)")
        if error == nil {
            var parsingError: NSError? = nil
            let parsedResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError) as! NSDictionary
            if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                // this closure runs in a background thread, so I have to access the data on a private queue
                self.privateQueueContext.performBlock( { self.gotNetResponse(photosDictionary) })

            } else {
                println("Can't find key 'photos' in \(parsedResult)")
            }
        }
        if error != nil { uiReportingClosure(error: error) }
    }


    private func gotNetResponse(photosDictionary: [String:AnyObject]) {
        println("gotNetResponse thread:\(NSThread.currentThread().description)")
        if let totalPages = photosDictionary["pages"] as? Int {
            self.totalPages = totalPages
            println("#Pages=\(totalPages)")
        }
        if let perPage = photosDictionary["perpage"] as? Int {
            self.perPage = perPage
            println("#Per Page=\(perPage)")
        }
        // I don't know why this one can only be read as a string?
        if let totalPhotoString = photosDictionary["total"] as? String {
            self.totalPhotos = (totalPhotoString as NSString).integerValue
            println("#Photos=\(self.totalPhotos)")
        }
        if let page = photosDictionary["page"] as? Int {
            self.currentPage = page
            println("#Page=\(page)")
        }
        dispatch_async(dispatch_get_main_queue(), { self.pinAnnotation.subtitle = PhotoLoader.numPhotosString(self.totalPhotos) })
        self.loadPhotos(photosDictionary["photo"] as! [[String: AnyObject]])
    }


    private func loadPhotos(photosArray: [[String: AnyObject]]) {
        println("loadPhotos thread:\(NSThread.currentThread().description)")

        var error: NSError? = nil
        let privateQPin = self.privateQueueContext.existingObjectWithID(pinAnnotation.pinRef.objectID, error: &error) as! Pin
        if error != nil { println("loadPhotos error: \(error)") }

        for aPhotoDictionary in photosArray {
            let photo = Photo(dictionary: aPhotoDictionary, pin: privateQPin, context: privateQueueContext)
        }
        self.privateQueueContext.save(&error)
        if error != nil { println("loadPhotos saving error: \(error)") }
   }

    var privateQueueContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.persistentStoreCoordinator = CoreDataStackManager.sharedInstance.managedObjectContext!.persistentStoreCoordinator
        return context
        }()


}