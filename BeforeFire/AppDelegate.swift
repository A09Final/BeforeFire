//
//  AppDelegate.swift
//  BeforeFire
//
//  Created by Ibnu Taufick Ahraza on 11/5/26.
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application (
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOption:
        [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map {
            String(format: "%02.2hhx", $0)
        }.joined()

        print("APNs Device Token: \(token)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error)")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
}
