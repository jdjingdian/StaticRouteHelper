//
//  CoreDataManager.swift
//  StaticRouteHelper
//
//  Created by Derek Jing on 2021/10/28.
//

import Foundation
import CoreData


class CoreDataManager {
    var persistantContainer:NSPersistentContainer
    
    
    init(){
        persistantContainer = NSPersistentContainer(name: "DataModel")
        persistantContainer.loadPersistentStores { (description,error) in
            if let error = error {
                fatalError("CoreData Failed: \(error.localizedDescription)")
            }
                
        }
    }
    
    func saveData(array:[routeData]){
        let routeData = RouteData(context: persistantContainer.viewContext)
//        do{
//            let arrayData = try NSKeyedArchiver.archivedData(withRootObject: array as Array, requiringSecureCoding: false)
//            routeData.values = arrayData
//            print(String(data: arrayData, encoding: .utf8)!)
//        }catch{
//            print("archived failed: \(error)")
//        }
        
        
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        do{
            let jsonData = try jsonEncoder.encode(array)
            routeData.values = jsonData
            print(String(data: jsonData, encoding: .utf8)!)
        }catch{
            print("Data encode failed: \(error)")
        }
        
        do{
            try persistantContainer.viewContext.save()
            
        }catch{
            print("viewContext saved failed: \(error)")
        }
    }
    
    func getAllData() -> [routeData] {
        let fetchRequest:NSFetchRequest<RouteData> = RouteData.fetchRequest()
        var list = [routeData]()
        let jsonDecoder = JSONDecoder()
        do{
            let arrayData = try persistantContainer.viewContext.fetch(fetchRequest)
            for n in arrayData {
                do{
                    list = try jsonDecoder.decode([routeData].self, from: n.values!)
                    print(list)
                }catch{
                    print("decode failed")
                }
               return list
            }
            
        }catch{
            print("Fetch data failed: \(error)")
            return []
        }
        return []
    }
    
    func resetData(){
        let storeContainer = persistantContainer.persistentStoreCoordinator

        // Delete each existing persistent store
        do{
            for store in storeContainer.persistentStores {
                try storeContainer.destroyPersistentStore(
                    at: store.url!,
                    ofType: store.type,
                    options: nil
                )
            }
        }catch{
            
        }
        

        // Re-create the persistent container
        persistantContainer = NSPersistentContainer(name: "DataModel")

        // Calling loadPersistentStores will re-create the
        // persistent stores
        persistantContainer.loadPersistentStores {
            (store, error) in
            // Handle errors
        }
    }
    
}
