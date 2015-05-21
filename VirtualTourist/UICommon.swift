//
//  UICommon.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/20/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import UIKit



class UICommon {

    static func errorAlert(title: String, message: String, inViewController: UIViewController, completion: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let cancelAction = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(cancelAction)
        dispatch_async(dispatch_get_main_queue(), {
            inViewController.presentViewController(alert, animated: true, completion: completion)
        })
    }


    static func errorAlert(title: String, message: String, inViewController: UIViewController) {
        errorAlert(title, message: message, inViewController: inViewController, completion: nil)
    }
}