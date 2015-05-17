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



    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "photoLoadedNotification:",
            name: PhotoLoader.NOTIFICATION_PHOTO_LOADED, object: nil)
    }
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }



    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBarHidden = false
    }


    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

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


    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Lay out the collection view so that cells take up 1/3 of the width,
        // with 1 space in between.
        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        layout.minimumLineSpacing = 1
        layout.minimumInteritemSpacing = 1

        let width = floor(self.collectionView.frame.size.width/3 - 1)
        layout.itemSize = CGSize(width: width, height: width)
        collectionView.collectionViewLayout = layout
    }



    func photoLoadedNotification(notification: NSNotification) {
        collectionView.reloadData()
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
        return currentPin.photos.count
    }


    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! PhotoCollectionViewCell

        var photoImage = UIImage(named: "Placeholder")

        let photo = currentPin.photos[indexPath.row]
        if photo.filePath != nil {
            cell.activityIndicator.stopAnimating()
            photoImage = photo.photoImage
        } else {
            cell.activityIndicator.startAnimating()
        }
        cell.photoImageView.image = photoImage
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
