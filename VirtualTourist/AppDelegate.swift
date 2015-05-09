//
//  AppDelegate.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/4/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {


         PersistenceManager.sharedInstance.initializeCoreData(initCoreDataCompletion)
        return true
    }



    private func initCoreDataCompletion(error: NSError?) -> Void {
        println("initCoreDataCompletion:\(NSThread.currentThread().description)")

        if error != nil {
            println("Error initializing CoreData:\n\(error)\n\n\(error!.userInfo)")
            return
        }

    }

}


