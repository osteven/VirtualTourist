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

class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate {


    // MARK: - Properties
    var currentPin: Pin!
    var currentAnnotation: PinLinkAnnotation!

    private var selectedIndexes = [NSIndexPath]()
    private var kvoContext: UInt8 = 1   // required to be a var

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    @IBOutlet weak var deleteSelectedButton: UIBarButtonItem!

    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext!
    }


    // MARK: - Lifecycle

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "photoLoadedNotification:",
            name: PhotoLoader.NOTIFICATION_PHOTO_LOADED, object: nil)
    }

    deinit { NSNotificationCenter.defaultCenter().removeObserver(self) }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBarHidden = false
        deleteSelectedButton.enabled = false
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //    selectedIndexes = [NSIndexPath]()       // unselect if coming back from detail
        //deleteSelectedButton.enabled = false
        //      collectionView.reloadData()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        let pointAnnotation = MKPointAnnotation()
        pointAnnotation.coordinate = currentPin.locationCoordinate
        pointAnnotation.title = currentPin.locationName
        pointAnnotation.subtitle = ""

        newCollectionButton.enabled = false
        if let loader = currentPin.photoListLoader {
            newCollectionButton.enabled = !loader.isLoadingPhotos
            loader.batchPhotosLoadedClosure = batchPhotosLoadedClosure
        }

        mapView.addAnnotation(pointAnnotation)
        let span = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        let region = MKCoordinateRegion(center: pointAnnotation.coordinate, span: span)
        self.mapView.centerCoordinate = pointAnnotation.coordinate
        self.mapView.setRegion(region, animated: true)

    }


    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        layout.minimumLineSpacing = 1
        layout.minimumInteritemSpacing = 1

        let width = floor(self.collectionView.frame.size.width/3 - 1)
        layout.itemSize = CGSize(width: width, height: width)
        collectionView.collectionViewLayout = layout
    }

    // MARK: - Actions
    @IBAction func newCollectionAction(sender: UIBarButtonItem) {
        deleteAllPhotos()
        self.newCollectionButton.enabled = false
        currentPin.photoListLoader!.load(uiReportingClosure, batchPhotosLoadedClosure: batchPhotosLoadedClosure)
    }

    @IBAction func deleteSelectedAction(sender: UIBarButtonItem) { deleteSelectedPhotos() }



    // MARK: - Utilities

    func photoLoadedNotification(notification: NSNotification) { collectionView.reloadData() }


    func batchPhotosLoadedClosure() {
        dispatch_async(dispatch_get_main_queue(), { self.newCollectionButton.enabled = true })
    }

    private func configureCell(cell: PhotoCollectionViewCell, atIndexPath indexPath: NSIndexPath) {
        if let index = find(selectedIndexes, indexPath) {
            cell.photoImageView.alpha = 0.5
            cell.informationButton.hidden = false
        } else {
            cell.photoImageView.alpha = 1.0
            cell.informationButton.hidden = true
        }
    }


    private func deleteAllPhotos() {
        currentPin.deleteAllPhotos(sharedContext)
        CoreDataStackManager.sharedInstance.saveContext()
        currentAnnotation!.updateSubtitle()
        selectedIndexes = [NSIndexPath]()
        deleteSelectedButton.enabled = false
        collectionView.reloadData()
    }


    func launchInformationViewController(photo: Photo) {
        let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoDetailViewController") as! PhotoDetailViewController
        controller.photo = photo
        self.navigationController?.pushViewController(controller, animated: true)
   }


    //TODO: error report
    func uiReportingClosure(annotation: MKPointAnnotation, error: NSError?) -> Void {
        if error != nil {
            println("PhotoAlbumViewController Error: \(error)")
            return
        }
    }


    private func deleteSelectedPhotos() {
        var photosToDelete = [Photo]()
        var indexPathsToDelete = [NSIndexPath]()

        for indexPath in selectedIndexes {
            photosToDelete.append(currentPin.photos[indexPath.row])
            indexPathsToDelete.append(indexPath)
        }
        for photo in photosToDelete {
            photo.photoImage = nil          // delete the disk file
            sharedContext.deleteObject(photo)
        }
        CoreDataStackManager.sharedInstance.saveContext()

        currentAnnotation.updateSubtitle()

        selectedIndexes = [NSIndexPath]()
        collectionView.performBatchUpdates({() -> Void in
            for indexPath in indexPathsToDelete {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
        }, completion: nil)

        deleteSelectedButton.enabled = false
        collectionView.reloadData()
    }



    // MARK: UICollectionViewDataSource


    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
       return currentPin.photos.count
    }


    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! PhotoCollectionViewCell
        cell.parentViewController = self

        var photoImage = UIImage(named: "Placeholder")
        let photo = currentPin.photos[indexPath.row]
        if photo.filePath != nil {
            cell.activityIndicator.stopAnimating()
            photoImage = photo.photoImage
        } else {
            cell.activityIndicator.startAnimating()
        }
        cell.photoImageView.image = photoImage
        cell.photo = photo
        configureCell(cell, atIndexPath: indexPath)
        return cell
    }



    // MARK: - UICollectionViewDelegate


    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {

        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
        if let index = find(selectedIndexes, indexPath) {
            selectedIndexes.removeAtIndex(index)
        } else {
            selectedIndexes.append(indexPath)
        }
        deleteSelectedButton.enabled = selectedIndexes.count > 0
        configureCell(cell, atIndexPath: indexPath)
    }




}
