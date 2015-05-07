//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/4/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import UIKit
import MapKit

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



    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        longPressGesture.addTarget(self, action: "handleLongPress:")
        mapView.addGestureRecognizer(longPressGesture)
        let mapRegion = getSavedMapRegion()
        dispatch_async(dispatch_get_main_queue(), { self.mapView.setRegion(mapRegion, animated: true) })
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



    // MARK: - Map support

    func handleLongPress(gestureRecognizer: UIGestureRecognizer) {

        if gestureRecognizer.state == UIGestureRecognizerState.Ended {
            let touchPoint = gestureRecognizer.locationInView(gestureRecognizer.view!)
            let touchMapCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView:mapView)
            println("press \(touchPoint) :: \(touchMapCoordinate.latitude), \(touchMapCoordinate.longitude)")
            let pointAnnotation = MKPointAnnotation()
            pointAnnotation.coordinate = touchMapCoordinate;
            pointAnnotation.title = "\(touchMapCoordinate.latitude), \(touchMapCoordinate.longitude)"
            pointAnnotation.subtitle = "tap to see photos"
            mapView.addAnnotation(pointAnnotation)
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
            reverseGeocode(view.annotation as! MKPointAnnotation)

        }
    }


    func mapView(mapView: MKMapView!, annotationView: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control == annotationView.rightCalloutAccessoryView {
            println("tap \(annotationView.annotation.title)")

            let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
            let nav = self.navigationController
            if nav == nil { println("nil") }
            //     controller.currentMeme = memeManager.memeAtIndex(indexPath.row)
            self.navigationController?.pushViewController(controller, animated: true)


        }
    }

    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }


    private func reverseGeocode(annotation: MKPointAnnotation) {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        geoCoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error) in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if error != nil  { /* do nothing, leave the latitude and logitude there */ return }

            let pmArray = placemarks as? [CLPlacemark]
            if pmArray == nil || pmArray!.count <= 0 { /* do nothing... */ return }

            let placeMark = pmArray![0]
            let formattedAddressLines = placeMark.addressDictionary["FormattedAddressLines"] as? NSArray

            if let addressStr = formattedAddressLines?.componentsJoinedByString(" ") {
                dispatch_async(dispatch_get_main_queue(), { annotation.title = addressStr })
            }
        })
    }

}




/*

[SubAdministrativeArea: Grady, 
State: OK, 
CountryCode: US, 
ZIP: 73010, 
Country: United States, 
Name: 73010, 
FormattedAddressLines: (
"Blanchard, OK  73010",
"United States"
), 
City: Blanchard]
*/





