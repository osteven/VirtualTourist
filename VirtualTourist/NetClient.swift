//
//  NetClient.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/9/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import Foundation
import MapKit

public typealias TaskRequestClosure = (data: NSData!, response: NSURLResponse!, error: NSError?) -> Void


class NetClient {

    private let genericSession = NSURLSession.sharedSession()
    private let BASE_URL = "https://api.flickr.com/services/rest/"
    private let METHOD_NAME = "flickr.photos.search"
    private let API_KEY = "263de36c553fc73f111b6634183cdb4f"
    private let SAFE_SEARCH = "1"
    private let EXTRAS = "url_m"
    private let DATA_FORMAT = "json"
    private let NO_JSON_CALLBACK = "1"

    static let sharedInstance = NetClient()
    private init() {}



    // MARK: - helper class function from The Movie Manager
    class func escapedParameters(parameters: [String : AnyObject]) -> String {
        var urlVars = [String]()
        for (key, value) in parameters {

            /* Make sure that it is a string value */
            let stringValue = "\(value)"

            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())

            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
        }

        return (!urlVars.isEmpty ? "?" : "") + join("&", urlVars)
    }


    func initPhotoListSearch(region: MKCoordinateRegion, completionHandler: TaskRequestClosure) {
        let methodArguments = [
                "method": METHOD_NAME,
                "api_key": API_KEY,
                "bbox": getMapBoundingBoxString(region),
                "safe_search": SAFE_SEARCH,
                "extras": EXTRAS,
                "format": DATA_FORMAT,
                "per_page": 100,
                "page": 1,
                "nojsoncallback": NO_JSON_CALLBACK
            ]
        loadSearchedFlickrPhotoList(methodArguments as! Dictionary<String,AnyObject>, completionHandler: completionHandler)
    }
    private func getMapBoundingBoxString(region: MKCoordinateRegion) -> String {
        let latitude = region.center.latitude
        let longitude = region.center.longitude
        let latitudeSpan = region.span.latitudeDelta
        let longitudeSpan = region.span.longitudeDelta
        let left = longitude - (longitudeSpan / 2.0)
        let right = longitude + (longitudeSpan / 2.0)
        let bottom = latitude - (latitudeSpan / 2.0)
        let top = latitude + (latitudeSpan / 2.0)
        return "\(left),\(bottom),\(right),\(top)"
    }
    


    private func loadSearchedFlickrPhotoList(methodArguments: [String : AnyObject], completionHandler: TaskRequestClosure) {
        let request = NSURLRequest(URL: NSURL(string: BASE_URL + NetClient.escapedParameters(methodArguments))!)
        let task = genericSession.dataTaskWithRequest(request, completionHandler: completionHandler)
        task.resume()
    }



    func getOnePhotoImage(urlString: String, session: NSURLSession, completionHandler: TaskRequestClosure) {
        let request = NSURLRequest(URL: NSURL(string: urlString)!)
        let task = session.dataTaskWithRequest(request, completionHandler: completionHandler)
        task.resume()
    }


}