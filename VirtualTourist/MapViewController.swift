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

    let longPressGesture = UILongPressGestureRecognizer()
    let geoCoder = CLGeocoder()

    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }

    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext!
     }

    private var loadPinCounter = 0
    private var savedMapRegionAtStartup: MKCoordinateRegion?
    //    private var currentPin: PinLinkAnnotation? = nil

    // MARK: - Life Cycle

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        //debugloadPhotos()
        // have to capture this at startup, because loading map pins overwrites it
        savedMapRegionAtStartup = getSavedMapRegion()

        longPressGesture.addTarget(self, action: "handleLongPress:")
        mapView.addGestureRecognizer(longPressGesture)
        self.loadPins()
        self.mapView.setRegion(self.savedMapRegionAtStartup!, animated: true)
    }


    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBarHidden = true
    }

    func saveMapRegion() {
        let dictionary = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
    }

    func getSavedMapRegion() -> MKCoordinateRegion {
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {

            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            let longitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)

            return MKCoordinateRegion(center: center, span: span)
        } else {
            let center = CLLocationCoordinate2D(latitude: mapView.region.center.latitude, longitude: mapView.region.center.longitude)
            let span = MKCoordinateSpan(latitudeDelta: mapView.region.span.latitudeDelta, longitudeDelta: mapView.region.span.longitudeDelta)
            return MKCoordinateRegion(center: center, span: span)
        }
    }




    private func debugloadPhotos() {
        println("debugloadPhotos thread:\(NSThread.currentThread().description)")
        let error: NSErrorPointer = nil
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        let results = self.sharedContext.executeFetchRequest(fetchRequest, error: error)
        if error != nil { println("Error in debugloadPhotos(): \(error)") }
        for photo in results! { println("\(photo)") }
    }

    private func loadPins() {
        //println("loadPins thread:\(NSThread.currentThread().description)")
        let error: NSErrorPointer = nil
        let fetchRequest = NSFetchRequest(entityName: "Pin")

        let results = self.sharedContext.executeFetchRequest(fetchRequest, error: error)
        //println("loadPins: \(results)")
        if error != nil {
            println("Error in loadPins(): \(error)")
            return
        }
        for pin in results as! [Pin] {
            let pointAnnotation = PinLinkAnnotation(pinRef: pin)
            pointAnnotation.coordinate = pin.locationCoordinate
            pointAnnotation.title = pin.locationName
            pointAnnotation.subtitle = PhotoListLoader.numPhotosString(pin.photos.count)
            self.mapView.addAnnotation(pointAnnotation)
        }

        //      self.clearAllPins()
   }

    private func clearAllPins() {
        let annotationArray = self.mapView.annotations.reverse()
        for annotation in annotationArray  {
            let plAnnotation = annotation as! PinLinkAnnotation
            self.sharedContext.deleteObject(plAnnotation.pinRef)
            self.mapView.removeAnnotation(plAnnotation)
        }
        CoreDataStackManager.sharedInstance.saveContext()
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

            let pointAnnotation = PinLinkAnnotation(pinRef: pin)
            pointAnnotation.coordinate = touchMapCoordinate
            pointAnnotation.title = title
            pointAnnotation.subtitle = "tap to see photos"

            mapView.addAnnotation(pointAnnotation)
            reverseGeocode(pointAnnotation)
            pin.photoListLoader = PhotoListLoader(forAnnotation: pointAnnotation,
                inRegion: mapView.region, withUIClosure: uiReportingClosure)
        }
    }


    //TODO: error report
    func uiReportingClosure(annotation: MKPointAnnotation, error: NSError?) -> Void {
        //println("uiReportingClosure thread:\(NSThread.currentThread().description)")
        if error != nil {
            println("Error: \(error)")
            return
        }
     }



    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {

        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinColor = .Purple
            pinView!.animatesDrop = true
            pinView!.draggable = true
            pinView!.rightCalloutAccessoryView = UIButton.buttonWithType(.DetailDisclosure) as! UIButton
        } else {
            pinView!.annotation = annotation
        }

        return pinView
    }





    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if newState == .Ending {
            reverseGeocode(view.annotation as! PinLinkAnnotation)

            // TODO: reload photos
        }
    }


    func mapView(mapView: MKMapView!, annotationView: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control == annotationView.rightCalloutAccessoryView {

            let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController

            controller.currentAnnotation = annotationView.annotation as! MKPointAnnotation
            controller.currentPin = (annotationView.annotation as! PinLinkAnnotation).pinRef
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }

    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }


    private func reverseGeocode(annotation: PinLinkAnnotation) {
        //println("reverseGeocode1 thread:\(NSThread.currentThread().description)")
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        geoCoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error) in
            //println("reverseGeocode2 thread:\(NSThread.currentThread().description)")
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if error != nil  { /* do nothing, leave the latitude and logitude there */ return }

            let pmArray = placemarks as? [CLPlacemark]
            if pmArray == nil || pmArray!.count <= 0 { /* do nothing... */ return }

            let placeMark = pmArray![0]
            let formattedAddressLines = placeMark.addressDictionary["FormattedAddressLines"] as? NSArray
            //println("reverseGeocode3 thread:\(NSThread.currentThread().description)")

            if let addressStr = formattedAddressLines?.componentsJoinedByString(" ") {
                //println("updating pin addressStr:\(addressStr)")

                annotation.pinRef.locationName = addressStr
                annotation.title = addressStr
                CoreDataStackManager.sharedInstance.saveContext()

            }
        })
    }








}








