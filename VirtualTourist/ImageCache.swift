//
//  File.swift
//  FavoriteActors
//
//  Created by Jason on 1/31/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

class ImageCache {
    
    private var inMemoryCache = NSCache()

    static let sharedInstance = ImageCache()
    private init() {}


    // MARK: - Retrieving images
    
    func imageWithIdentifier(identifier: String?) -> UIImage? {
        
        // If the identifier is nil, or empty, return nil
        if identifier == nil || identifier! == "" { return nil }
        
        let path = pathForIdentifier(identifier!)

        // First try the memory cache
        if let image = inMemoryCache.objectForKey(path) as? UIImage {
            return image
        }
        
        // Next Try the hard drive
        if let data = NSData(contentsOfFile: path) {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    // MARK: - Saving images
    
    func storeImage(image: UIImage?, withIdentifier identifier: String) -> String? {
        let path = pathForIdentifier(identifier)
        
        // If the image is nil, remove images from the cache
        if image == nil {
            inMemoryCache.removeObjectForKey(path)
            do {
                try NSFileManager.defaultManager().removeItemAtPath(path)
            } catch _ {
            }
            return nil
        }
        
        // Otherwise, keep the image in memory
        inMemoryCache.setObject(image!, forKey: path)
        
        // And in documents directory
        guard let data = UIImagePNGRepresentation(image!) else { fatalError("failed UIImagePNGRepresentation") }
        data.writeToFile(path, atomically: true)
        return path
    }


    func createStorageDirectory(uniquePinID: String) {
        let path = pathForIdentifier(uniquePinID)
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
        } catch _ {
        }
    }


    // MARK: - Helper
    
    func pathForIdentifier(identifier: String) -> String {
        guard let documentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory,
            inDomains: .UserDomainMask).first
            else { fatalError("Failed to get DocumentDirectory") }
        let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
        
        return fullURL.path!
    }
}