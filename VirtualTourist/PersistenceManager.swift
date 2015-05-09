//
//  PersistenceManager.swift
//  VirtualTourist
//
//  Created by Steven O'Toole on 5/4/15.
//  Copyright (c) 2015 Steven O'Toole. All rights reserved.
//
/*
    based on: http://martiancraft.com/blog/2015/03/core-data-stack/
            https://github.com/xhruso00/ModernCoreData

    more resources:
    http://www.objc.io/issue-4/
    https://developer.apple.com/library/ios/documentation/Cocoa/Reference/CoreDataFramework/Classes/NSManagedObjectContext_Class/index.html
    http://oleb.net/blog/2014/06/core-data-concurrency-debugging/
    http://stackoverflow.com/questions/13806849/handling-errors-in-addpersistentstorewithtype
    http://applidium.com/en/news/core_data_features_ios8_part_2/

    http://stackoverflow.com/questions/2310216/implementation-of-automatic-lightweight-migration-for-core-data-iphone
    http://stackoverflow.com/questions/1830079/iphone-core-data-automatic-lightweight-migration?rq=1
*/


import Foundation
import CoreData

public typealias InitCallBack = (error: NSError?) -> Void


class PersistenceManager {

    // MARK: - Properties

    static let sharedInstance = PersistenceManager()

    var isLoaded = false
    let managedObjectContext: NSManagedObjectContext
    private let privateManagedObjectContext: NSManagedObjectContext


    private lazy var applicationDocumentsDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls.last as! NSURL
    }()



    // MARK: - init
    private init() {
        managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        privateManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        managedObjectContext.parentContext = privateManagedObjectContext
    }

    private func getManagedObjectModel(baseName: String) -> NSManagedObjectModel {
        let modelURL = NSBundle.mainBundle().URLForResource(baseName, withExtension: "momd")!
        let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL)
        assert(managedObjectModel != nil, "NSManagedObjectModel failed")
        return managedObjectModel!
    }


    func initializeCoreData(initCallback: InitCallBack?) -> Void {
        let baseName = NSBundle.mainBundle().infoDictionary!["CFBundleName"] as! String
        initializeCoreData(baseName, initCallback: initCallback)
    }

    /* 
    */
    func initializeCoreData(baseName: String, initCallback: InitCallBack?) -> Void {
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("\(baseName).sqlite")
        println("sqlite path: \(url.path!)")
        println("initializeCoreData thread:\(NSThread.currentThread().description)")

        let options: [NSObject: AnyObject] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
            ]

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: getManagedObjectModel(baseName))
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
            println("initializeCoreData BG thread:\(NSThread.currentThread().description)")
            var error: NSError? = nil
            if coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil,
                URL: url, options: options, error: &error) == nil {
                error = self.errorWithFailedPersistentStore(error!)
            } else {
                self.privateManagedObjectContext.persistentStoreCoordinator = coordinator
                self.isLoaded = true
            }
            if initCallback != nil {
                dispatch_sync(dispatch_get_main_queue(), { initCallback!(error: error) })
            } else if error != nil {
                println("Error initializing CoreData:\n\(error)\n\n\(error!.userInfo)")
            }
        })
   }






    private func errorWithFailedPersistentStore(originalError: NSError) -> NSError {
        let dict = NSMutableDictionary()
        dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
        dict[NSLocalizedFailureReasonErrorKey] = "There was an error creating or loading the application's saved data."
        dict[NSUnderlyingErrorKey] = originalError
        let error = NSError(domain: "com.o2l.error", code: 9999, userInfo: dict as [NSObject : AnyObject])
        NSLog("Unresolved error \(error), \(error.userInfo)")
        return error
    }


    // MARK: - save
    // TODO: add save closure
    func save() {
        if !self.managedObjectContext.hasChanges && !self.privateManagedObjectContext.hasChanges {
            println("no changes to save")
            return
        }
        var error: NSError? = nil
        if !self.managedObjectContext.save(&error) {
            NSLog("Unresolved error \(error), \(error!.userInfo)")
            abort()
        }
        self.privateManagedObjectContext.performBlock {
            var privateError: NSError? = nil
            self.privateManagedObjectContext.save(&privateError)
            if privateError != nil {
                NSLog("Unresolved private error \(privateError), \(privateError!.userInfo)")
                abort()
            }
        }
    }

}