//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/7/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import UIKit
import MapKit
import CoreData

let reuseIdentifier = "PhotoAlbumCell"

class PhotoAlbumViewController: UIViewController {


    var currentPin: Pin!

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!

    var mainQueueContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBarHidden = false

        var error: NSError? = nil
        currentPin = self.mainQueueContext.existingObjectWithID(currentPin!.objectID, error: &error) as! Pin


        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Register cell classes
        self.collectionView!.registerClass(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        println("PhotoAlbumViewController, pin=\(currentPin)")

    }


    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)


        println("PhotoAlbumViewController viewDidAppear thread:\(NSThread.currentThread().description)")
        println("currentPin-->photos:\(currentPin.photos)")



        let pointAnnotation = MKPointAnnotation()
        pointAnnotation.coordinate = currentPin.locationCoordinate
        pointAnnotation.title = currentPin.locationName
        pointAnnotation.subtitle = ""

        mapView.addAnnotation(pointAnnotation)
        let span = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        let region = MKCoordinateRegion(center: pointAnnotation.coordinate, span: span)
        self.mapView.centerCoordinate = pointAnnotation.coordinate
        self.mapView.setRegion(region, animated: true)

    }



    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UICollectionViewDataSource


    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        println("numberOfItemsInSection count=\(currentPin.photos.count)")
        return currentPin.photos.count
    }
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! PhotoCollectionViewCell
        println("cellForItemAtIndexPath currentPin:\(currentPin.description)")

        let phArray: [Photo] = currentPin.photos
        println("\(phArray)")
        let photo = currentPin.photos[indexPath.row]
        cell.descriptionLabel.text = photo.description
        return cell
    }



    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(collectionView: UICollectionView, shouldHighlightItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(collectionView: UICollectionView, shouldShowMenuForItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, canPerformAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) -> Bool {
        return false
    }

    override func collectionView(collectionView: UICollectionView, performAction action: Selector, forItemAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
    
    }
    */

}
