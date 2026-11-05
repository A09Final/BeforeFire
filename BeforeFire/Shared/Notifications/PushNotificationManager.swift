//
//  PushNotificationManager.swift
//  BeforeFire
//
//  Created by Ibnu Taufick Ahraza on 11/5/26.
//

import UIKit
import UserNotifications

final class PushNotificationManager {
    
    static let shared = PushNotificationManager()
    
    private init () {}
    
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            
            if let error = error {
                print ("Print Notification Error: \(error)")
                return
            }
            
            guard granted else {
                print ("Notifications Permission Denied")
                return
            }
            
            DispatchQueue.main.async{
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}
