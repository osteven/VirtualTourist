//
//  PhotoCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/12/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import UIKit

class PhotoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var informationButton: UIButton!

    var photo: Photo!
    var parentViewController: PhotoAlbumViewController!

    @IBAction func informationButtonAction(sender: UIButton) {
        parentViewController.launchInformationViewController(photo)
    }
}
