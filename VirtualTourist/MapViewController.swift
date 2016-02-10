//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/4/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate {

    // MARK: - Properties
    @IBOutlet weak var mapView: MKMapView!

    private let longPressGesture = UILongPressGestureRecognizer()
    private let geoCoder = CLGeocoder()
    private var savedMapRegionAtStartup: MKCoordinateRegion?

    var filePath : String {
        let manager = NSFileManager.defaultManager()
        guard let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first
            else { fatalError("Failed to get DocumentDirectory") }
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }

    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext!
     }



    // MARK: - Life Cycle


    override func viewDidLoad() {
        super.viewDidLoad()

        // have to capture this at startup, because loading map pins overwrites it
        savedMapRegionAtStartup = getSavedMapRegion()

        longPressGesture.addTarget(self, action: "handleLongPress:")
        mapView.addGestureRecognizer(longPressGesture)
        self.loadPinsFromDatabase()
        self.mapView.setRegion(self.savedMapRegionAtStartup!, animated: true)
    }


    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBarHidden = true
    }

    // MARK: - Map support

    func handleLongPress(gestureRecognizer: UIGestureRecognizer) {

        if gestureRecognizer.state == UIGestureRecognizerState.Ended {
            let touchPoint = gestureRecognizer.locationInView(gestureRecognizer.view!)
            let touchMapCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView:mapView)

            let temporaryTitle = "\(touchMapCoordinate.latitude), \(touchMapCoordinate.longitude)"
            let dictionary: [String: AnyObject] = [Pin.Keys.Latitude: touchMapCoordinate.latitude,
                Pin.Keys.Longitude: touchMapCoordinate.longitude, Pin.Keys.LocationName: temporaryTitle]

            let pin = Pin(dictionary: dictionary, context: self.sharedContext)
            CoreDataStackManager.sharedInstance.saveContext()

            // title and subtitle will be updated after the reverse geocode and photo searches
            let pointAnnotation = PinLinkAnnotation(pinRef: pin)
            pointAnnotation.coordinate = touchMapCoordinate
            pointAnnotation.title = temporaryTitle
            pointAnnotation.subtitle = "tap to see photos"

            mapView.addAnnotation(pointAnnotation)
            reverseGeocode(pointAnnotation)
            pin.photoListFetcher = PhotoListFetcher(forAnnotation: pointAnnotation,
                inRegion: mapView.region)
            pin.photoListFetcher!.fetchFlickrPhotoList(uiReportingClosure, batchPhotosFetchedClosure: nil)
        }
    }


    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinColor = .Purple
            pinView!.animatesDrop = true
            pinView!.draggable = true
            pinView!.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
        } else {
            pinView!.annotation = annotation
        }
        return pinView
    }


    // Handle pin dragged.  Like dropping a new pin, except the coordinate is already set.
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if newState == .Ending {
            let pinLinkAnnotation = view.annotation as! PinLinkAnnotation
            let pin = (view.annotation as! PinLinkAnnotation).pinRef
            pin.latitude = pinLinkAnnotation.coordinate.latitude
            pin.longitude = pinLinkAnnotation.coordinate.longitude
            pin.locationName = "\(pinLinkAnnotation.coordinate.latitude), \(pinLinkAnnotation.coordinate.longitude)"
            pin.totalAvailablePhotos = 0
            pin.deleteAllPhotos(sharedContext)
            CoreDataStackManager.sharedInstance.saveContext()
            pinLinkAnnotation.title = pin.locationName
            pinLinkAnnotation.subtitle = "tap to see photos"
            reverseGeocode(pinLinkAnnotation)
            // set a new fetcher for the new region
            pin.photoListFetcher = PhotoListFetcher(forAnnotation: pinLinkAnnotation, inRegion: mapView.region)
            pin.photoListFetcher!.fetchFlickrPhotoList(uiReportingClosure, batchPhotosFetchedClosure: nil)
        }
    }


    func mapView(mapView: MKMapView, annotationView: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control != annotationView.rightCalloutAccessoryView { return }

        let selectedPin = (annotationView.annotation as! PinLinkAnnotation).pinRef
        if selectedPin.photoListFetcher == nil {
            /* if the pin was loaded from the database, the photos were too and there is no loader yet.  You 
                might need one if the user selects "New Collection"
            */
            selectedPin.photoListFetcher = PhotoListFetcher(forAnnotation: annotationView.annotation as! PinLinkAnnotation,
                inRegion: mapView.region)
        }

        let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
        controller.currentAnnotation = annotationView.annotation as! PinLinkAnnotation
        controller.currentPin = selectedPin
        self.navigationController?.pushViewController(controller, animated: true)
    }


    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }


    private func reverseGeocode(annotation: PinLinkAnnotation) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        geoCoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error) in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if error != nil  { /* do nothing, leave the latitude and logitude there */ return }

            guard let pmArray = placemarks where pmArray.count > 0 else { /* do nothing... */ return  }

            let placeMark = pmArray[0]
            guard let formattedAddressLines = placeMark.addressDictionary?["FormattedAddressLines"] as? NSArray
                else { /* do nothing... */ return  }

            let addressStr = formattedAddressLines.componentsJoinedByString(" ")
            annotation.pinRef.locationName = addressStr
            annotation.title = addressStr
            CoreDataStackManager.sharedInstance.saveContext()
        })
    }
    



    // MARK: - Utilities

    func uiReportingClosure(error: NSError?) -> Void {
        if error != nil {
            UICommon.errorAlert("Flickr API Failure",
                message: "Could not fetch photos from Flickr\n\n[\(error!.localizedDescription)]",
                inViewController: self)
        }
    }

    private func saveMapRegion() {
        let dictionary = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
    }

    private func getSavedMapRegion() -> MKCoordinateRegion {
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String: AnyObject] {
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            let longitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)

            return MKCoordinateRegion(center: center, span: span)
        } else {
            let center = CLLocationCoordinate2D(latitude: mapView.region.center.latitude,
                longitude: mapView.region.center.longitude)
            let span = MKCoordinateSpan(latitudeDelta: mapView.region.span.latitudeDelta,
                longitudeDelta: mapView.region.span.longitudeDelta)
            return MKCoordinateRegion(center: center, span: span)
        }
    }
    

    private func loadPinsFromDatabase() {
        var error: NSError? = nil
        let fetchRequest = NSFetchRequest(entityName: "Pin")

        let results: [AnyObject]?
        do {
            results = try self.sharedContext.executeFetchRequest(fetchRequest)
        } catch let error1 as NSError {
            error = error1
            results = nil
        }
        if error != nil {
            UICommon.errorAlert("Database Failure", message: "Could not load the saved pins\n\n[\(error!.localizedDescription)]", inViewController: self)
            return
        }
        for pin in results as! [Pin] {
            let pointAnnotation = PinLinkAnnotation(pinRef: pin)
            pointAnnotation.coordinate = pin.locationCoordinate
            pointAnnotation.title = pin.locationName
            pointAnnotation.updateSubtitle()
            self.mapView.addAnnotation(pointAnnotation)
        }
    }
    
    




}








