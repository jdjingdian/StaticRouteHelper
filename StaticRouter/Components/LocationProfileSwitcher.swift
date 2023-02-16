//
//  LocationProfileSwitcher.swift
//  Static Router
//
//  Created by 经典 on 15/1/2023.
//

import Foundation
import SwiftUI

class LocationProfileSwitcher: ObservableObject {
    @Published private var profiles = LocationProfiles()
    
    var location_profiles: Array<LocationProfiles.LocationProfile> {
        return profiles.locationConfSets;
    }
    
    //MARK: USER INTENT
    func CreateNewProfile(){
        profiles.CreateProfile()
    }
    
    func DeleteProfile(_ id: Int?){
        guard let index = id else{
            return
        }
        profiles.Delete(index)
    }
    
    func GetDefaultProfile() -> LocationProfiles.LocationProfile {
        profiles.GetDefault()
    }
}
