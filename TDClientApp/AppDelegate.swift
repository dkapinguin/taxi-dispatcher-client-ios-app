//
//  AppDelegate.swift
//  TDClientApp
//
//  Created by Станислав Полтароков on 10.12.17.
//  Copyright © 2017 Станислав Полтароков. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var inBackground: Bool?
    var authentificate: Bool?
    var noAuthCounter = 0;

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        return true
    }
    
    func isInBackground() -> Bool {
        return inBackground == nil ? false : inBackground!
    }
    
    func isAuthentificate() -> Bool {
        return authentificate == nil ? false : authentificate!
    }
    
    func setAuthentificate() {
        print("client authentificated")
        authentificate = true
    }
    
    func unsetAuthentificate() {
        print("client not authentificated")
        authentificate = false
    }
    
    //Запрашивает во всплывающем диалоге 10 значный телефон клиента
    func requireClientPhone(timer : Timer) {
        let alert = UIAlertController(title: "Введите Ваш номер телефона",
                                      message: "Формат 10 цифр",
                                      preferredStyle: .alert)
        
        // Submit button
        let submitAction = UIAlertAction(title: "ОК", style: .default, handler: { (action) -> Void in
            // Get 1st TextField's text
            let textField = alert.textFields![0]
            let defaults = UserDefaults.standard
            defaults.set(textField.text!, forKey: "clientPhone")
        })
        
        // Cancel button
        let cancel = UIAlertAction(title: "Отмена", style: .destructive, handler: { (action) -> Void in })
        
        // Add 1 textField and cutomize it
        alert.addTextField { (textField: UITextField) in
            textField.keyboardAppearance = .dark
            textField.keyboardType = .default
            textField.autocorrectionType = .default
            textField.placeholder = "9001234567"
            textField.clearButtonMode = .whileEditing
            
        }
        
        // Add action buttons and present the Alert
        alert.addAction(submitAction)
        alert.addAction(cancel)
        //self.present(alert, animated: true, completion: nil)
        
        timer.invalidate()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        inBackground = true
        print("to background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        inBackground = false
        print("to foreground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

