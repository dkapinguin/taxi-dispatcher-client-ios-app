//
//  FirstViewController.swift
//  TDClientApp
//
//  Created by Станислав Полтароков on 10.12.17.
//  Copyright © 2017 Станислав Полтароков. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import SocketIO

class FirstViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var orderBtn:UIButton!
    @IBOutlet weak var cancelBtn:UIButton!
    @IBOutlet weak var statusLabel:UILabel!
    @IBOutlet weak var fromAdres:UITextField!
    @IBOutlet weak var toAdres:UITextField!
    @IBOutlet weak var mapView:MKMapView! //
    let socket = SocketIOClient(socketURL: URL(string:"http://91.203.169.42:8081")!)
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    //let driverAnnotation = MKAnnotation()
    private var locationManager: CLLocationManager!
    private var currentLocation: CLLocation?
    private var clientOrdersCount = 0
    private var isPhoneAlertOpen = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        addHandlers()
        socket.connect()
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        if (CLLocationManager.locationServicesEnabled())
        {
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
        }
        
        if (isUncorrectPhoneSetting()) {
            Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(requireClientPhone(timer:)), userInfo: nil, repeats: true)
        }
        
        Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(requestStatus), userInfo: nil, repeats: true)
    }
    
    func getPlacemarkFromLocation(location: CLLocation){
        CLGeocoder().reverseGeocodeLocation(location, completionHandler:
            {(placemarks, error) in
                if (error != nil) {
                    print("reverse geodcode fail: \(String(describing: error?.localizedDescription))")
                }
                //let pm = placemarks as! [CLPlacemark]
                //if pm.count > 0 {
                    //self.showAddPinViewController(placemarks[0] as CLPlacemark)
    
                //}
        })
    }
    
    func getLocationAddress(location:CLLocation) {
        let geocoder = CLGeocoder()
        
        print("-> Finding user address...")
        
        geocoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error)->Void in
            var placemark:CLPlacemark!
            
            if error == nil && placemarks!.count > 0 {
                placemark = placemarks![0] as CLPlacemark
                
                var addressString : String = ""
                if placemark.isoCountryCode == "TW" /*Address Format in Chinese*/ {
                    if placemark.country != nil {
                        addressString = placemark.country!
                    }
                    /*if placemark.subAdministrativeArea != nil {
                        addressString = addressString + placemark.subAdministrativeArea + ", "
                    }
                    if placemark.postalCode != nil {
                        addressString = addressString + placemark.postalCode + " "
                    }
                    if placemark.locality != nil {
                        addressString = addressString + placemark.locality
                    }
                    if placemark.thoroughfare != nil {
                        addressString = addressString + placemark.thoroughfare
                    }
                    if placemark.subThoroughfare != nil {
                        addressString = addressString + placemark.subThoroughfare
                    }*/
                } else {
                    if placemark.subThoroughfare != nil {
                        addressString = placemark.subThoroughfare! + " "
                    }
                    /*if placemark.thoroughfare != nil {
                        addressString = addressString + placemark.thoroughfare + ", "
                    }
                    if placemark.postalCode != nil {
                        addressString = addressString + placemark.postalCode + " "
                    }
                    if placemark.locality != nil {
                        addressString = addressString + placemark.locality + ", "
                    }
                    if placemark.administrativeArea != nil {
                        addressString = addressString + placemark.administrativeArea + " "
                    }
                    if placemark.country != nil {
                        addressString = addressString + placemark.country
                    }*/
                }
                
                print(addressString)
            }
        })
    }

    
    // MARK - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        defer { currentLocation = locations.last }
        
        if currentLocation == nil {
            // Zoom to user location
            if let userLocation = locations.last {
                let viewRegion = MKCoordinateRegionMakeWithDistance(userLocation.coordinate, 2000, 2000)
                mapView.setRegion(viewRegion, animated: false)
            }
        }
        
        /*var g = CLGeocoder()
        var p:CLPlacemark?
        let mynil = "empty"
        g.reverseGeocodeLocation(currentLocation!, completionHandler: {
            (placemarks, error) in
            let pm = placemarks as? [CLPlacemark]
            if ((pm != nil) && pm?.count > 0){
                // p = CLPlacemark()
                p = CLPlacemark(placemark: pm?[0] as CLPlacemark)
                
                println("Inside what is in p: \(p?.country ? p?.country : mynil)")
                
            }
            
        })
        
        print("Outside what is in p: \(p?.country ? p?.country : mynil)")*/
    }
    
    //Return true if phone setting is incorrect on null
    func isUncorrectPhoneSetting() -> Bool {
        let defaults = UserDefaults.standard
        let clientPhone = defaults.string(forKey: "clientPhone")
        
        return clientPhone == nil || clientPhone?.count != 10
    }
    
    func getSettingsValue(settingName: String) -> String {
        let defaults = UserDefaults.standard
        //var defVal =
        
        return defaults.object(forKey: settingName) != nil ?
            defaults.string(forKey: settingName)! : "-1"
    }
    
    func convertDictToJSONString(data: Dictionary<String, Any>) -> [String:String]? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            // here "jsonData" is the dictionary encoded in JSON data
            
            let decoded = try JSONSerialization.jsonObject(with: jsonData, options: [])
            // here "decoded" is of type `Any`, decoded from JSON data
            
            // you can now cast it with the right type
            if let dictFromJSON = decoded as? [String:String] {
                // use dictFromJSON
                return dictFromJSON
            }
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }
    
    //Request taxi order status of client account from server
    func requestStatus() {
        if appDelegate.isAuthentificate() {
            appDelegate.noAuthCounter = 0
            sendStatusRequest()
            return
        }
        appDelegate.noAuthCounter += 1
        
        if self.appDelegate.isInBackground() && appDelegate.noAuthCounter > 10 {
            print("I'm in background without authentificate > 10 status iteration - exit!")
            exit(0)
        }
        
        if !isUncorrectPhoneSetting() {
            let identData = [ "id": getSettingsValue(settingName: "clientId") , "phone" : getSettingsValue(settingName: "clientPhone")] as [String : Any]
            
            socket.emit("ident", convertDictToJSONString(data: identData)!)
        }
    }
    
    //Запрашивает во всплывающем диалоге 10 значный телефон клиента
    func requireClientPhone(timer : Timer) {
        if isPhoneAlertOpen {
            return
        }
        if !isUncorrectPhoneSetting() {
            timer.invalidate()
            return
        }
        
        let alert = UIAlertController(title: "Введите Ваш номер телефона",
                                      message: "Формат 10 цифр",
                                      preferredStyle: .alert)
        
        // Submit button
        let submitAction = UIAlertAction(title: "ОК", style: .default, handler: { (action) -> Void in
            // Get 1st TextField's text
            let textField = alert.textFields![0]
            let defaults = UserDefaults.standard
            defaults.set(textField.text!, forKey: "clientPhone")
            self.isPhoneAlertOpen = false
        })
        
        // Cancel button
        let cancel = UIAlertAction(title: "Отмена", style: .destructive, handler: { (action) -> Void in
            self.isPhoneAlertOpen = false
        })
        
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
        isPhoneAlertOpen = true
        present(alert, animated: true, completion: nil)
    }
    
    //Показывает сообщение во всплывающем диалоге
    func showMessageAlert(title: String, message: String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        
        //  Ok button
        let okAction = UIAlertAction(title: "Ok", style: .destructive, handler: { (action) -> Void in })
        
        // Add action button and present the Alert
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            view.endEditing(true)
        }
        super.touchesBegan(touches, with: event)
    }
    
    @IBAction func mapTouch(_ sender: Any) {
        
    }
    
    //Touch order button
    @IBAction func touchOrder(_ sender: Any) {
        if !appDelegate.isAuthentificate() || self.clientOrdersCount > 0 {
            showMessageAlert(title: "Заказ не создан!", message: "Нет соединения или есть активный заказ!")
            return
        }
        
        if let startAdr = fromAdres.text {
            if startAdr.count == 0 {
                showMessageAlert(title: "Заказ не создан!", message: "Пустой адрес подачи машины (откуда)!")
                return
            }
            let endAdr = toAdres.text != nil ? toAdres.text! : ""
            sendOrderRequest(startAdr: startAdr, endAdr: endAdr)
            sendStatusRequest()
        }
    }
    
    //Touch cancel button
    @IBAction func touchCancel(_ sender: Any) {
        if !appDelegate.isAuthentificate() || self.clientOrdersCount == 0 {
            showMessageAlert(title: "Отмена невозможна!", message: "Нет соединения или нет активного заказа!")
            return
        }
        
        let alert = UIAlertController(title: "Отменить заказ?",
                                      message: "Подтверждение отмены заказа",
                                      preferredStyle: .alert)
        
        // Submit button
        let submitAction = UIAlertAction(title: "Да", style: .default, handler: { (action) -> Void in
            self.sendCancelRequest()
            self.sendStatusRequest()
        })
        
        // Cancel button
        let cancel = UIAlertAction(title: "Нет", style: .destructive, handler: { (action) -> Void in })
        
        // Add action buttons and present the Alert
        alert.addAction(submitAction)
        alert.addAction(cancel)
        present(alert, animated: true, completion: nil)
    }
    
    func convertJSONStringToDict(text: String?) -> [String: Any]? {
        if text == nil {
            return nil
        }
        if let data = text!.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    func parseClientStatusDict(data: Dictionary<String, Any>) {
        if let orderCountVal = data["ocn"],
            let orderCount = Int(orderCountVal as! String) {
            
            self.clientOrdersCount = orderCount
            
            var statusInfo = ""
            var index = 0
            while index < orderCount {
                var orderCondition = "Выполняется: "
                let indexStr = String(index)
                let orderStatus = data["ors" + indexStr] != nil ? Int(data["ors" + indexStr] as! String) ?? -1 : -1;
                let remoteClientStatus = data["rcst" + indexStr] != nil ? Int(data["rcst" + indexStr] as! String) ?? -1 : 0;
                let onPlaceStatus = data["opl" + indexStr] != nil ? Int(data["opl" + indexStr] as! String) ?? 0 : 0;
                let tmeterStatus = data["tmh" + indexStr] != nil ? (data["tmh" + indexStr] as! String).count : 0;
                if remoteClientStatus == -2 {
                    orderCondition = "Нет машин: "
                } else if remoteClientStatus == -1 {
                    orderCondition = "Удаление заказа: "
                } else if orderStatus >= 0 && orderStatus < 8 {
                    orderCondition = "Поиск машины: "
                } else if orderStatus == 8 {
                    if tmeterStatus == 0 {
                        orderCondition = "Машина отправлена: "
                        if onPlaceStatus == 1 {
                            orderCondition = "Машина ожидает: "
                        }
                    }
                } else if orderStatus == 26 {
                    orderCondition = "Заказ завершен: "
                }
                statusInfo += orderCondition + (data["odt" + indexStr] as! String) + " "
                index += 1
            }
            
            if orderCount > 0 {
                statusLabel.text = statusInfo;
                return
            } else if self.appDelegate.isInBackground() {
                print("I'm in background without orders - exit!")
                exit(0)
            }
        }
        
        self.clientOrdersCount = 0
        statusLabel.text = "Нет активных заказов."
    }
    
    func sendCancelRequest() {
        let cancelRequestData = [ "id": getSettingsValue(settingName: "clientId") , "phone" : getSettingsValue(settingName: "clientPhone")] as [String : Any]
        emitRequestWithDictData(event: "cancel order", data: cancelRequestData)
    }
    
    func sendStatusRequest() {
        let statusRequestData = [ "cid": getSettingsValue(settingName: "clientId") , "clphone" : getSettingsValue(settingName: "clientPhone")] as [String : Any]
        socket.emit("status", convertDictToJSONString(data: statusRequestData)!)
    }
    
    func sendOrderRequest(startAdr: String, endAdr: String) {
        let orderRequestData = [ "id": getSettingsValue(settingName: "clientId") , "phone" : getSettingsValue(settingName: "clientPhone"),
            "stadr" : startAdr, "enadr" : endAdr] as [String : Any]
        emitRequestWithDictData(event: "new order", data: orderRequestData)
    }
    
    func emitRequestWithDictData(event: String, data: Dictionary<String, Any>) {
        if let eventData = convertDictToJSONString(data: data) {
            socket.emit(event, eventData)
        }
    }
    
    func addHandlers() {
        socket.on("auth") {[weak self] data, ack in
            if let dataDictionary = data[0] as? Dictionary<String, Any>,
                let clientId = dataDictionary["client_id"] {

                let defaults = UserDefaults.standard
                defaults.set(clientId, forKey: "clientId")

                self?.sendStatusRequest()
                self?.appDelegate.setAuthentificate()
            }
            return
        }
        
        socket.on("clstat") {[weak self] data, ack in
            if let dataDictionary = data[0] as? Dictionary<String, Any>, let clientStatusJSONStr = dataDictionary["cl_status"], let statusData = self?.convertJSONStringToDict(text: clientStatusJSONStr as? String) {
                
                self?.parseClientStatusDict(data: statusData)
            }
            return
        }
        
        socket.on("req_decline") {[weak self] data, ack in
            if let dataDictionary = data[0] as? Dictionary<String, Any>, let status = dataDictionary["status"] as? String {
                if status == "many_new_order_req" {
                    self?.showMessageAlert(title: "Слишком частая операция!",
                                           message: "Повторите операцию чуть позже (1 мин)!")
                }
            }
            return
        }
        
        socket.on("connect") {[weak self] data, ack in
            self?.appDelegate.noAuthCounter = 0
            self?.statusLabel.text = "Подключаюсь..."
            self?.requestStatus()
        }

        socket.on("disconnect") {[weak self] data, ack in
            self?.statusLabel.text = "Подключаюсь..."
            self?.appDelegate.unsetAuthentificate()
        }
        
        socket.on("error") {[weak self] data, ack in
            self?.statusLabel.text = "Подключаюсь..."
            self?.appDelegate.unsetAuthentificate()
        }
        
        //socket.onAny {print("Got event: \($0.event), with items: \($0.items!)")}
    }
    

}

