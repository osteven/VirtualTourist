//
//  PhotoDetailViewController.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/18/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import UIKit
import CoreData

class PhotoDetailViewController: UIViewController {

    // MARK: - Properties
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var commentsTableView: UITableView!

    var photo: Photo!
    var privateQueueContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = CoreDataStackManager.sharedInstance.managedObjectContext
        return context
        }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        photoImageView.image = photo.photoImage
        titleLabel.text = photo.title
        if photo.comments.count == 0 {
            CommentListLoader(photo: photo).fetchFlickrCommentList(nil, batchCommentsLoadedClosure: commentsLoadedClosure)
        }
    }


    // MARK: - Comments Loaded
    func commentsLoadedClosure() {
        commentsTableView.reloadData()
    }



    // MARK: - UITableViewDataSource support
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return photo.comments.count
    }


    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCellWithIdentifier("CommentCell") else { fatalError("Cannot find CommentCell") }
        let comment = photo.comments[indexPath.row]

        cell.textLabel?.text = comment.authorName + " " + comment.getDateAsString()
        cell.detailTextLabel?.text = comment.content

        return cell
    }


}
