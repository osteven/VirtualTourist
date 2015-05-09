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
        //        return CoreDataStackManager.sharedInstance.managedObjectContext!
        return PersistenceManager.sharedInstance.managedObjectContext
    }
    private var loadPinCounter = 0
    private var savedMapRegionAtStartup: MKCoordinateRegion?

    // MARK: - Life Cycle

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // have to capture this at startup, because loading map pins overwrites it
        savedMapRegionAtStartup = getSavedMapRegion()

        longPressGesture.addTarget(self, action: "handleLongPress:")
        mapView.addGestureRecognizer(longPressGesture)
        dispatch_async(dispatch_get_main_queue(), { self.loadPins() })
        dispatch_async(dispatch_get_main_queue(), { self.mapView.setRegion(self.savedMapRegionAtStartup!, animated: true) })
    }


    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBarHidden = true
        //      let savedMapRegionAtStartup = getSavedMapRegion()
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


    private func loadPins() {
        if !PersistenceManager.sharedInstance.isLoaded {
            loadPinCounter++
            println("loadPins: #\(loadPinCounter)")
            if loadPinCounter >= 200 { println("failed to loadPins"); return }
            dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC)));
            dispatch_async(dispatch_get_main_queue(), { self.loadPins() })
           return
        }
        let error: NSErrorPointer = nil
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        let results = sharedContext.executeFetchRequest(fetchRequest, error: error)
        println("loadPins: \(results)")
        if error != nil {
            println("Error in loadPins(): \(error)")
            return
        }
        for pin in results as! [Pin] {
            let pointAnnotation = PinLinkAnnotation(pinRef: pin)
            pointAnnotation.coordinate = pin.locationCoordinate
            pointAnnotation.title = pin.locationName
            pointAnnotation.subtitle = "tap to see photos"
            mapView.addAnnotation(pointAnnotation)
        }
    }

    // MARK: - Map support

    func handleLongPress(gestureRecognizer: UIGestureRecognizer) {

        if gestureRecognizer.state == UIGestureRecognizerState.Ended {
            let touchPoint = gestureRecognizer.locationInView(gestureRecognizer.view!)
            let touchMapCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView:mapView)

            println("handleLongPress thread:\(NSThread.currentThread().description)")
            let temporaryTitle = "\(touchMapCoordinate.latitude), \(touchMapCoordinate.longitude)"
            let dictionary: [String: AnyObject] = [Pin.Keys.Latitude: touchMapCoordinate.latitude,
                Pin.Keys.Longitude: touchMapCoordinate.longitude, Pin.Keys.LocationName: temporaryTitle]
            let pin = Pin(dictionary: dictionary, context: sharedContext)

            let pointAnnotation = PinLinkAnnotation(pinRef: pin)
            println("PinLinkAnnotation created:\(pointAnnotation.description)")
            //   let pointAnnotation = MKPointAnnotation()
            pointAnnotation.coordinate = touchMapCoordinate;
            pointAnnotation.title = temporaryTitle
            pointAnnotation.subtitle = "tap to see photos"
            mapView.addAnnotation(pointAnnotation)
            PersistenceManager.sharedInstance.save()
            reverseGeocode(pointAnnotation)
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
//            let droppedAt = view.annotation.coordinate
//            println("drop \(droppedAt.latitude), \(droppedAt.longitude)")
            reverseGeocode(view.annotation as! PinLinkAnnotation)

        }
    }


    func mapView(mapView: MKMapView!, annotationView: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control == annotationView.rightCalloutAccessoryView {
            //          println("tap \(annotationView.annotation.title)")



            let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
//            let nav = self.navigationController
//            if nav == nil { println("nil") }

            println("mvc=\(mapView.centerCoordinate.latitude), \(mapView.centerCoordinate.longitude); \( mapView.region.span.latitudeDelta), \( mapView.region.span.longitudeDelta)")

            controller.currentPin = (annotationView.annotation as! PinLinkAnnotation).pinRef
            self.navigationController?.pushViewController(controller, animated: true)


        }
    }

    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }


    private func reverseGeocode(annotation: PinLinkAnnotation) {
        println("reverseGeocode1 thread:\(NSThread.currentThread().description)")
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        geoCoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error) in
            println("reverseGeocode2 thread:\(NSThread.currentThread().description)")
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if error != nil  { /* do nothing, leave the latitude and logitude there */ return }

            let pmArray = placemarks as? [CLPlacemark]
            if pmArray == nil || pmArray!.count <= 0 { /* do nothing... */ return }

            let placeMark = pmArray![0]
            let formattedAddressLines = placeMark.addressDictionary["FormattedAddressLines"] as? NSArray

            if let addressStr = formattedAddressLines?.componentsJoinedByString(" ") {
                println("got PinLinkAnnotation:\(annotation)")

                println("updating pin addressStr:\(addressStr)")
                annotation.pinRef.locationName = addressStr
                PersistenceManager.sharedInstance.save()
                dispatch_async(dispatch_get_main_queue(), { annotation.title = addressStr })
            }
        })
    }

}








