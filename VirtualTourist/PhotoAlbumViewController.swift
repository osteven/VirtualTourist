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


class PhotoAlbumViewController: UIViewController, UICollectionViewDelegate {


    // MARK: - Properties
    var currentPin: Pin!
    var currentAnnotation: PinLinkAnnotation!

    private var selectedIndexes = [NSIndexPath]()
    private let REUSE_IDENTIFIER = "PhotoAlbumCell"

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    @IBOutlet weak var deleteSelectedButton: UIBarButtonItem!

    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext!
    }


    // MARK: - Lifecycle

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "photoFetchedNotification:",
            name: PhotoFetcher.NOTIFICATION_PHOTO_FETCHED, object: nil)
    }

    deinit { NSNotificationCenter.defaultCenter().removeObserver(self) }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBarHidden = false
        deleteSelectedButton.enabled = false
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        let pointAnnotation = MKPointAnnotation()
        pointAnnotation.coordinate = currentPin.locationCoordinate
        pointAnnotation.title = currentPin.locationName
        pointAnnotation.subtitle = ""

        newCollectionButton.enabled = false
        if let fetcher = currentPin.photoListFetcher {
            newCollectionButton.enabled = !fetcher.isFetchingPhotos
            fetcher.batchPhotosFetchedClosure = batchPhotosFetchedClosure
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
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let width = floor(self.collectionView.frame.size.width/3)
        layout.itemSize = CGSize(width: width, height: width)
        collectionView.collectionViewLayout = layout
    }

    // MARK: - Actions
    @IBAction func newCollectionAction(sender: UIBarButtonItem) {
        deleteAllPhotos()
        self.newCollectionButton.enabled = false
        currentPin.photoListFetcher!.fetchFlickrPhotoList(uiReportingClosure, batchPhotosFetchedClosure: batchPhotosFetchedClosure)
    }

    @IBAction func deleteSelectedAction(sender: UIBarButtonItem) { deleteSelectedPhotos() }



    // MARK: - Utilities

    func photoFetchedNotification(notification: NSNotification) { collectionView.reloadData() }


    func batchPhotosFetchedClosure() {
        dispatch_async(dispatch_get_main_queue(), { self.newCollectionButton.enabled = true })
    }

    private func configureCell(cell: PhotoCollectionViewCell, atIndexPath indexPath: NSIndexPath) {
        if let _ = selectedIndexes.indexOf(indexPath) {
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



    func uiReportingClosure(error: NSError?) -> Void {
        if error != nil {
            UICommon.errorAlert("Flickr API Failure", message: "Could not fetch photos from Flickr\n\n[\(error!.localizedDescription)]", inViewController: self)
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
            photo.deleteComments(sharedContext)
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
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(REUSE_IDENTIFIER,
            forIndexPath: indexPath) as! PhotoCollectionViewCell
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
        if let index = selectedIndexes.indexOf(indexPath) {
            selectedIndexes.removeAtIndex(index)
        } else {
            selectedIndexes.append(indexPath)
        }
        deleteSelectedButton.enabled = selectedIndexes.count > 0
        configureCell(cell, atIndexPath: indexPath)
    }




}
