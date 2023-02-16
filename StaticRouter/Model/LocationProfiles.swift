//
//  LocationConfigurationCore.swift
//  Static Router
//
//  Created by 经典 on 14/1/2023.
//

import Foundation

struct LocationProfiles {
    private(set) var locationConfSets: Array<LocationProfile>
    private(set) var profilesIdSets: Array<Int>
    init() {
        profilesIdSets = Array<Int>()
        locationConfSets = Array<LocationProfile>()
        locationConfSets.append(LocationProfile(removeable: false, configName: "Default", routesIdSets: Array<Int>(), id: 0))
        profilesIdSets.append(0)
        locationConfSets.append(LocationProfile(removeable: false, configName: "Edit Location...", routesIdSets: Array<Int>(), id: 1))
        profilesIdSets.append(1)
        
    }
    
    
    
    
    struct LocationProfile: Identifiable, Hashable {
        let removeable: Bool
        var configName: String
        var routesIdSets: Array<Int>
        var id: Int
    }
    
    //MARK: USER INTENT
    
    mutating func LinkRouteToProfile(){
        
    }
    
    mutating func UnlinkRouteToProfile(){
        
    }
    
    mutating func CreateProfile(){
        let profileId = CalcProfileId()
        locationConfSets.append(LocationProfile(removeable: true, configName: "untitled-\(profileId)", routesIdSets: Array<Int>(), id:profileId))
        profilesIdSets.append(profileId)
    }
    
    func CalcProfileId() -> Int {
        return (profilesIdSets.max() ?? 1)+1
    }
    
    mutating func Delete(_ id: Int){
        var isProfileFound = false;
        guard let index = locationConfSets.firstIndex(where: {
            if($0.id == id){
                isProfileFound = true
                return true
            }
            return false
        }) else{
            return
        }
        if(isProfileFound){
            if(locationConfSets[index].removeable){
                print("delete index: \(index)")
                locationConfSets.remove(at: index)
            }
        }
    }
    
    func GetDefault() -> LocationProfile {
        return locationConfSets[0]
    }
    
}
