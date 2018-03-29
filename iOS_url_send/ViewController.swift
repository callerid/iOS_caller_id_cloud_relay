//
//  ViewController.swift
//  iOS_url_send
//
//  Created by mac on 9/6/17.
//  Copyright © 2017 CallerId.com. All rights reserved.
//

import UIKit
import CocoaAsyncSocket

class ViewController: UIViewController, GCDAsyncUdpSocketDelegate {
    
    let log_datasource_delegate = CallLogDataView()
    
    // define CallerID.com regex strings used for parsing CallerID.com hardware formats
    let callRecordPattern = "(\\d\\d) ([IO]) ([ES]) (\\d{4}) ([GB]) (.)(\\d) (\\d\\d/\\d\\d \\d\\d:\\d\\d [AP]M) (.{8,15})(.*)"
    let detailedPattern = "(\\d\\d) ([NFR]) {13}(\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d)"
    
    // --------------------------------------------------------------------------------------
    
    let sDataSuppliedUrl = "supplied_url"
    let sDataUsingSuppliedUrl = "using_supplied_url"
    let sDataUsingDeluxeUnit = "using_deluxe_unit"
    let sDataServer = "server"
    
    let sDataParamLine = "param_line"
    let sDataParamTime = "param_time"
    let sDataParamPhone = "param_phone"
    let sDataParamName = "param_name"
    let sDataParamIO = "param_io"
    let sDataParamSE = "param_se"
    let sDataParamStatus = "param_status"
    let sDataParamDuration = "param_duration"
    let sDataParamRingNumber = "param_ring_number"
    let sDataParamRingType = "param_ring_type"
    
    let sDataUsingAuth = "using_auth"
    let sDataUsername = "username"
    let sDataPassword = "password"
    
    let sDataGenUrl = "generated_url"
    var totalPackets:Int = 0
    let debugMode:Bool = false
    var previousReceived = [String: Int]()
    
    
    // UI References
    @IBOutlet weak var tbSuppliedUrl: UITextField!
    @IBOutlet weak var tbServer: UITextField!
    @IBOutlet weak var tbLine: UITextField!
    @IBOutlet weak var tbDateTime: UITextField!
    @IBOutlet weak var tbNumber: UITextField!
    @IBOutlet weak var tbName: UITextField!
    @IBOutlet weak var tbIO: UITextField!
    @IBOutlet weak var tbSE: UITextField!
    @IBOutlet weak var tbStatus: UITextField!
    @IBOutlet weak var tbDuration: UITextField!
    @IBOutlet weak var tbRings: UITextField!
    @IBOutlet weak var tbRingType: UITextField!
    
    @IBOutlet weak var lbGeneratedUrl: UILabel!
    
    @IBOutlet weak var tbUserName: UITextField!
    @IBOutlet weak var tbPassword: UITextField!
    
    
    @IBOutlet weak var chooser_supplied_or_built: UISegmentedControl!
    @IBOutlet weak var chooser_deluxe_or_basic: UISegmentedControl!
    @IBOutlet weak var chooser_auth_or_no_auth: UISegmentedControl!
    
    @IBOutlet weak var tbv_log: UITableView!
    
    @IBOutlet weak var btnTest: UIButton!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        totalPackets = 0
        
        NotificationCenter.default.addObserver(self, selector: #selector(goesToBackground), name: .UIApplicationWillResignActive, object: nil)
        
        // Create database if not already created
        _ = DBManager.shared.createDatabase()
        
        // Start UDP receiver
        startServer()
        
        // Link log data
        tbv_log.dataSource = log_datasource_delegate
        tbv_log.delegate = log_datasource_delegate
        
        // Load up previous values
        let defaults = UserDefaults.standard
        
        // If first run
        if(defaults.string(forKey: sDataUsingSuppliedUrl) == nil){
            return
        }
        
        // Supplied URL
        tbSuppliedUrl.text = defaults.string(forKey: sDataSuppliedUrl)!
        
        // Supplied vs Built
        let usingSupplied = defaults.bool(forKey: sDataUsingSuppliedUrl)
        if(usingSupplied){
            chooser_supplied_or_built.selectedSegmentIndex = 0
            btnTest.setTitle("Test Supplied URL", for: .normal)
        }
        else{
            chooser_supplied_or_built.selectedSegmentIndex = 1
            lbGeneratedUrl.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            btnTest.setTitle("Test Built URL", for: .normal)
        }
        
        // Deluxe or Basic
        let usingDeluxe = defaults.bool(forKey: sDataUsingDeluxeUnit)
        if(usingDeluxe){
            
            chooser_deluxe_or_basic.selectedSegmentIndex = 1
            
            tbIO.isEnabled = true
            tbSE.isEnabled = true
            tbStatus.isEnabled = true
            tbDuration.isEnabled = true
            tbRings.isEnabled = true
            tbRingType.isEnabled = true
            
            tbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
        }
        else{
            chooser_deluxe_or_basic.selectedSegmentIndex = 0
            
            tbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
        }
        
        tbServer.text = defaults.string(forKey: sDataServer)!
        
        tbLine.text = defaults.string(forKey: sDataParamLine)!
        tbDateTime.text = defaults.string(forKey: sDataParamTime)!
        tbNumber.text = defaults.string(forKey: sDataParamPhone)!
        tbName.text = defaults.string(forKey: sDataParamName)!
        tbIO.text = defaults.string(forKey: sDataParamIO)!
        tbSE.text = defaults.string(forKey: sDataParamSE)!
        tbStatus.text = defaults.string(forKey: sDataParamStatus)!
        tbDuration.text = defaults.string(forKey: sDataParamDuration)!
        tbRings.text = defaults.string(forKey: sDataParamRingNumber)!
        tbRingType.text = defaults.string(forKey: sDataParamRingType)!
        
        // Using auth.
        let usingAuth = defaults.bool(forKey: sDataUsingAuth)
        if(usingAuth){
            chooser_auth_or_no_auth.selectedSegmentIndex = 0
        }
        else{
            chooser_auth_or_no_auth.selectedSegmentIndex = 1
        }
        
        tbUserName.text = defaults.string(forKey: sDataUsername)!
        tbPassword.text = defaults.string(forKey: sDataPassword)!
        
        lbGeneratedUrl.text = defaults.string(forKey: sDataGenUrl)!
        
        // Enable/Disable based on loaded settings
        chooser_supplied_url_or_custom_ValueChange((Any).self)
        chooser_deluxe_unit_or_basic_unit_ValueChanged((Any).self)
        
        // Load up log
        let results = DBManager.shared.getPreviousLog(limit: 25)
        
        for entry in results.reversed() {
            addToLog(text: entry)
        }
        
        // Duplicate handling ticker
        _ = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(dups_timer_tick), userInfo: nil, repeats: true)
        
    }
    
    func dups_timer_tick(){
        
        if(previousReceived.isEmpty){
            return
        }
        
        // Create key list
        var keys_to_remove = [String]()
        var keys_to_inccrement = [String]()
        
        for (key, _) in previousReceived{
            
            if(previousReceived[key]! > 4){
                keys_to_remove.append(key)
            }
            else{
                keys_to_inccrement.append(key)
            }
        }
        
        for key in keys_to_inccrement{
            previousReceived[key] = previousReceived[key]! + 1
        }
        
        for key in keys_to_remove{
            previousReceived.removeValue(forKey: key)
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(false)
        
        save_settings()
        
    }
    
    func goesToBackground(_ notification: Notification) {
        save_settings()
    }
    
    func save_settings(){
        
        // Save all settings
        let defaults = UserDefaults.standard
        defaults.set(tbSuppliedUrl.text, forKey: sDataSuppliedUrl)
        defaults.set(chooser_supplied_or_built.selectedSegmentIndex==0, forKey: sDataUsingSuppliedUrl)
        defaults.set(chooser_deluxe_or_basic.selectedSegmentIndex==1, forKey: sDataUsingDeluxeUnit)
        defaults.set(tbServer.text, forKey: sDataServer)
        
        defaults.set(tbLine.text, forKey: sDataParamLine)
        defaults.set(tbDateTime.text, forKey: sDataParamTime)
        defaults.set(tbNumber.text, forKey: sDataParamPhone)
        defaults.set(tbName.text, forKey: sDataParamName)
        defaults.set(tbIO.text, forKey: sDataParamIO)
        defaults.set(tbSE.text, forKey: sDataParamSE)
        defaults.set(tbStatus.text, forKey: sDataParamStatus)
        defaults.set(tbDuration.text, forKey: sDataParamDuration)
        defaults.set(tbRings.text, forKey: sDataParamRingNumber)
        defaults.set(tbRingType.text, forKey: sDataParamRingType)
        
        defaults.set(chooser_auth_or_no_auth.selectedSegmentIndex==0, forKey: sDataUsingAuth)
        defaults.set(tbUserName.text, forKey: sDataUsername)
        defaults.set(tbPassword.text, forKey: sDataPassword)
        
        defaults.set(lbGeneratedUrl.text, forKey: sDataGenUrl)
        
    }
    
    func addToLog(text:String){
        
        if(log_datasource_delegate.addToLog(data: text)){
            
            let log_data_count = log_datasource_delegate.getLogDataCount()
            
            tbv_log.beginUpdates()
            tbv_log.insertRows(at: [IndexPath(row: log_data_count-1, section: 0)], with: .automatic)
            tbv_log.endUpdates()
         
            let indexPath = NSIndexPath(item: log_datasource_delegate.getLogDataCount()-1, section: 0)
            tbv_log.scrollToRow(at: indexPath as IndexPath, at: UITableViewScrollPosition.middle, animated: true)
            
        }
        
    }
    
    @IBAction func btnClearLog_Click(_ sender: Any) {
        
        log_datasource_delegate.clear()
        _ = DBManager.shared.executeQuery(query: "DELETE FROM calls;")
        tbv_log.reloadData()
        
    }
    
    @IBAction func btnCopyGenUrl_Click(_ sender: Any) {
        
        UIPasteboard.general.string = lbGeneratedUrl.text
        
    }
    
    @IBOutlet weak var lbServer: UILabel!
    
    @IBOutlet weak var btnGenerateUrl: UIButton!
    @IBOutlet weak var lbDevSection: UILabel!
    @IBOutlet weak var lbLine: UILabel!
    @IBOutlet weak var lbTime: UILabel!
    @IBOutlet weak var lbPhone: UILabel!
    @IBOutlet weak var lbName: UILabel!
    @IBOutlet weak var lbIO: UILabel!
    @IBOutlet weak var lbSE: UILabel!
    @IBOutlet weak var lbStatus: UILabel!
    @IBOutlet weak var lbDuration: UILabel!
    @IBOutlet weak var lbRings: UILabel!
    @IBOutlet weak var lbRingType: UILabel!
    
    @IBOutlet weak var lbLineD: UILabel!
    @IBOutlet weak var lbTimeD: UILabel!
    @IBOutlet weak var lbNumberD: UILabel!
    @IBOutlet weak var lbNameD: UILabel!
    @IBOutlet weak var lbIOD: UILabel!
    @IBOutlet weak var lbSED: UILabel!
    @IBOutlet weak var lbStatusD: UILabel!
    @IBOutlet weak var lbDurationD: UILabel!
    @IBOutlet weak var lbRingsD: UILabel!
    @IBOutlet weak var lbRingTypeD: UILabel!
    
    @IBOutlet weak var lbCIDVarsHeader: UILabel!
    @IBOutlet weak var lbYourVarHeader: UILabel!
    @IBOutlet weak var lbDesHeader: UILabel!
    
    @IBAction func chooser_supplied_url_or_custom_ValueChange(_ sender: Any) {
        
        let isSupplied = chooser_supplied_or_built.selectedSegmentIndex == 0
        
        if(isSupplied){
            
            btnTest.setTitle("Test Supplied URL", for: .normal)
            lbGeneratedUrl.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbDesHeader.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbCIDVarsHeader.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbYourVarHeader.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            tbLine.isEnabled = false
            tbDateTime.isEnabled = false
            tbNumber.isEnabled = false
            tbName.isEnabled = false
            tbIO.isEnabled = false
            tbSE.isEnabled = false
            tbStatus.isEnabled = false
            tbDuration.isEnabled = false
            tbRings.isEnabled = false
            tbRingType.isEnabled = false
            tbServer.isEnabled = false
            
            tbLine.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbDateTime.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbNumber.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbName.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbServer.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDevSection.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbLine.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbTime.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbPhone.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbName.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbLineD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbTimeD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbNumberD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbNameD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbIOD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbSED.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbStatusD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDurationD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingsD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingTypeD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbServer.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            btnGenerateUrl.isEnabled = false
        }
        else
        {
            
            btnTest.setTitle("Test Built URL", for: .normal)
            lbGeneratedUrl.textColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
            
            lbDesHeader.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbCIDVarsHeader.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbYourVarHeader.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            tbLine.isEnabled = true
            tbDateTime.isEnabled = true
            tbNumber.isEnabled = true
            tbName.isEnabled = true
            tbServer.isEnabled = true
            
            let isDeluxed = chooser_deluxe_or_basic.selectedSegmentIndex == 1
            
            if(isDeluxed){
                
                tbIO.isEnabled = true
                tbSE.isEnabled = true
                tbStatus.isEnabled = true
                tbDuration.isEnabled = true
                tbRings.isEnabled = true
                tbRingType.isEnabled = true
                
                tbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                tbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                
                lbIOD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbSED.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbStatusD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbDurationD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbRingsD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbRingTypeD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                
                lbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                lbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
                
            }
            else{
                
                tbIO.isEnabled = false
                tbSE.isEnabled = false
                tbStatus.isEnabled = false
                tbDuration.isEnabled = false
                tbRings.isEnabled = false
                tbRingType.isEnabled = false
                
                tbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                tbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                
                lbIOD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbSED.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbStatusD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbDurationD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbRingsD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbRingTypeD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                
                lbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                lbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
                
            }
            
            tbLine.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbDateTime.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbNumber.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbName.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)

            tbServer.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbDevSection.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbLine.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbTime.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbPhone.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbName.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbLineD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbTimeD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbNumberD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbNameD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbServer.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            btnGenerateUrl.isEnabled = true
            
            
        }
        
    }
    
    @IBAction func chooser_deluxe_unit_or_basic_unit_ValueChanged(_ sender: Any) {
    
        let isSupplied = chooser_supplied_or_built.selectedSegmentIndex == 0
        
        if(isSupplied){
            return
        }
        
        let isDeluxed = chooser_deluxe_or_basic.selectedSegmentIndex == 1
        
        if(isDeluxed){
            
            tbIO.isEnabled = true
            tbSE.isEnabled = true
            tbStatus.isEnabled = true
            tbDuration.isEnabled = true
            tbRings.isEnabled = true
            tbRingType.isEnabled = true
            
            tbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbIOD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbSED.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbStatusD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbDurationD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbRingsD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbRingTypeD.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
            lbIO.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbSE.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbStatus.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbDuration.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbRings.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            lbRingType.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            
        }
        else{
            
            tbIO.isEnabled = false
            tbSE.isEnabled = false
            tbStatus.isEnabled = false
            tbDuration.isEnabled = false
            tbRings.isEnabled = false
            tbRingType.isEnabled = false
            
            tbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            tbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbIOD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbSED.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbStatusD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDurationD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingsD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingTypeD.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
            lbIO.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbSE.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbStatus.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbDuration.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRings.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            lbRingType.textColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
            
        }
        
    }
    
    func showPopup(title:String, message:String){
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        
    }
    
    // SQL Log Commands
    func insertIntoSql(line:String,
                       time:String,
                       phone:String,
                       name:String,
                       io:String,
                       se:String,
                       status:String,
                       duration:String,
                       ringNumber:String,
                       ringType:String,
                       checksum:String)
    {
        DBManager.shared.addToLog(dateTime: time, line: line, type: io, indicator: se, dur: duration, checksum: checksum, rings: ringNumber, num: phone, name: name)
        
    }
    @IBAction func btnTest_Click(_ sender: Any) {
        
        let usingAuth:Bool = chooser_auth_or_no_auth.selectedSegmentIndex == 0
        
        if(usingAuth){
            if(tbUserName.text == ""){
                showPopup(title: "Authenication not setup properly.", message: "Using authentication requires at least a username. Example call NOT sent.")
                return
            }
        }
        
        let usingSupplied:Bool = chooser_supplied_or_built.selectedSegmentIndex == 0
        
        if(usingSupplied){
            
            post_url(urlPost: tbSuppliedUrl.text!, line: "01", time: "01/01 12:00 PM", phone: "770-263-7111", name: "CallerID.com", io: "I", se: "S", status: "x", duration: "0030", ringNumber: "03", ringType: "A")
            
            showPopup(title: "Example Call Sent", message: "Call was sent to supplied URL.")
            
        }
        else{
            
            post_url(urlPost: lbGeneratedUrl.text!, line: "01", time: "01/01 12:00 PM", phone: "770-263-7111", name: "CallerID.com", io: "I", se: "S", status: "x", duration: "0030", ringNumber: "03", ringType: "A")
            
            showPopup(title: "Example Call Sent", message: "Call was sent to built URL.")
            
        }
        
    }
    @IBAction func btnPaste_Click(_ sender: Any) {
        paste_to_url()
    }
    
    @IBAction func btnGenerate_Click(_ sender: Any) {
        generate_web_url()
        showPopup(title: "Setup Complete", message: "Double check built URL for accuracy. Click 'Test Built URL' to send example call to server.")
    }
    
    // Generating web address
    func generate_web_url()
    {
        
        var genUrl = tbServer.text! + "?"
        
        if(tbLine.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbLine.text!.replacingOccurrences(of: " ", with: "") + "=%Line&"
        }
        
        if(tbDateTime.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbDateTime.text!.replacingOccurrences(of: " ", with: "") + "=%Time&"
        }
        
        if(tbNumber.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbNumber.text!.replacingOccurrences(of: " ", with: "") + "=%Phone&"
        }
        
        if(tbName.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbName.text!.replacingOccurrences(of: " ", with: "") + "=%Name&"
        }
        if(tbIO.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbIO.text!.replacingOccurrences(of: " ", with: "") + "=%IO&"
        }
        if(tbSE.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbSE.text!.replacingOccurrences(of: " ", with: "") + "=%SE&"
        }
        if(tbStatus.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbStatus.text!.replacingOccurrences(of: " ", with: "") + "=%Status&"
        }
        if(tbDuration.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbDuration.text!.replacingOccurrences(of: " ", with: "") + "=%Duration&"
        }
        if(tbRings.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbRings.text!.replacingOccurrences(of: " ", with: "") + "=%RingNumber&"
        }
        if(tbRingType.text?.replacingOccurrences(of: " ", with: "") != ""){
            genUrl = genUrl + tbRingType.text!.replacingOccurrences(of: " ", with: "") + "=%RingType&"
        }
        
        if(genUrl.replacingOccurrences(of: " ", with: "") == "?"){
            
            lbGeneratedUrl.text = "[failed to generate URL, please make sure you have at least one parameter set]"
            return
        }
        
        // Return generated string
        lbGeneratedUrl.text = genUrl.substring(to: genUrl.index(before: genUrl.endIndex))
        
    }
    
    // Gets clipboard text and paste into program
    func paste_to_url(){
        
        let clipboardText = clipboardContent()
        
        if(clipboardText == nil){
            
            showPopup(title: "Failed", message: "No text found in Clipboard.")
            return
            
        }
        
        let urlParts = clipboardText?.components(separatedBy: "?")
        
        if(urlParts?.count != 2){
            
            showPopup(title: "Failed", message: "Text found on Clipboard is not in correct format.")
            return
            
        }
        
        let urlString = urlParts?[0]
        let params = urlParts?[1]
        
        tbServer.text = urlString!
        
        if(parseParams(params: params!)){
            
            showPopup(title: "Setup Complete", message: "Pasted Successfully, you can test pasted URL with a call or the 'Test Supplied URL' button.")
            
            tbSuppliedUrl.text = clipboardText!
            lbGeneratedUrl.text = clipboardText!
            return
            
        }
        
        showPopup(title: "Failed", message: "Text found on Clipboard is not in correct format.")
        
    }
    
    // Patterns
    let linePattern = "([&]?([A-Za-z0-9_-]+)=%Line)"
    let ioPattern = "([&]?([A-Za-z0-9_-]+)=%IO)"
    let sePattern = "([&]?([A-Za-z0-9_-]+)=%SE)"
    let durationPattern = "([&]?([A-Za-z0-9_-]+)=%Duration)"
    let ringTypePattern = "([&]?([A-Za-z0-9_-]+)=%RingType)"
    let ringNumberPattern = "([&]?([A-Za-z0-9_-]+)=%RingNumber)"
    let timePattern = "([&]?([A-Za-z0-9_-]+)=%Time)"
    let phonePattern = "([&]?([A-Za-z0-9_-]+)=%Phone)"
    let namePattern = "([&]?([A-Za-z0-9_-]+)=%Name)"
    let statusPattern = "([&]?([A-Za-z0-9_-]+)=%Status)"
    
    func parseParams(params:String) -> Bool{
        
        // Setup varibles
        var line_variableName = ""
        var time_variableName = ""
        var phone_variableName = ""
        var name_variableName = ""
        var io_variableName = ""
        var se_variableName = ""
        var status_variableName = ""
        var duration_variableName = ""
        var ringNumber_variableName = ""
        var ringType_variableName = ""
        
        // Capture variables from params string
        let lineMatch = params.capturedGroups(withRegex: linePattern)
        if(lineMatch.count>1){
            line_variableName = lineMatch[1]
        }
        
        let timeMatch = params.capturedGroups(withRegex: timePattern)
        if(timeMatch.count>1){
            time_variableName = timeMatch[1]
        }
        
        let phoneMatch = params.capturedGroups(withRegex: phonePattern)
        if(phoneMatch.count>1){
            phone_variableName = phoneMatch[1]
        }
        
        let nameMatch = params.capturedGroups(withRegex: namePattern)
        if(nameMatch.count>1){
            name_variableName = nameMatch[1]
        }
        
        let ioMatch = params.capturedGroups(withRegex: ioPattern)
        if(ioMatch.count>1){
            io_variableName = ioMatch[1]
        }
        
        let seMatch = params.capturedGroups(withRegex: sePattern)
        if(seMatch.count>1){
            se_variableName = seMatch[1]
        }
        
        let statusMatch = params.capturedGroups(withRegex: statusPattern)
        if(statusMatch.count>1){
            status_variableName = statusMatch[1]
        }
        
        let durationMatch = params.capturedGroups(withRegex: durationPattern)
        if(durationMatch.count>1){
            duration_variableName = durationMatch[1]
        }
        
        let ringNumberMatch = params.capturedGroups(withRegex: ringNumberPattern)
        if(ringNumberMatch.count>1){
            ringNumber_variableName = ringNumberMatch[1]
        }
        
        let ringTypeMatch = params.capturedGroups(withRegex: ringTypePattern)
        if(ringTypeMatch.count>1){
            ringType_variableName = ringTypeMatch[1]
        }
        
        
        // Display variables
        tbLine.text = line_variableName
        tbDateTime.text = time_variableName
        tbNumber.text = phone_variableName
        tbName.text = name_variableName
        tbIO.text = io_variableName
        tbSE.text = se_variableName
        tbStatus.text = status_variableName
        tbDuration.text = duration_variableName
        tbRings.text = ringNumber_variableName
        tbRingType.text = ringType_variableName
        
        return true
        
    }
    
    // Send $_POST to Cloud server
    func post_url(urlPost:String,
                  line:String,
                  time:String,
                  phone:String,
                  name:String,
                  io:String,
                  se:String,
                  status:String,
                  duration:String,
                  ringNumber:String,
                  ringType:String)
    {
        
        let urlParts = urlPost.components(separatedBy: "?")
        let urlString = urlParts[0]
        var usingParams = urlParts[1]
        
        // Replace CallerID variables with actual data
        usingParams = usingParams.replacingOccurrences(of: "%Line", with: line)
        usingParams = usingParams.replacingOccurrences(of: "%Time", with: time)
        usingParams = usingParams.replacingOccurrences(of: "%Phone", with: phone)
        usingParams = usingParams.replacingOccurrences(of: "%Name", with: name)
        usingParams = usingParams.replacingOccurrences(of: "%IO", with: io)
        usingParams = usingParams.replacingOccurrences(of: "%SE", with: se)
        usingParams = usingParams.replacingOccurrences(of: "%Status", with: status)
        usingParams = usingParams.replacingOccurrences(of: "%Duration", with: duration)
        usingParams = usingParams.replacingOccurrences(of: "%RingNumber", with: ringNumber)
        usingParams = usingParams.replacingOccurrences(of: "%RingType", with: ringType)
        
        // Create request
        let fullUrl = urlString + "?" + usingParams
        let requestUrl = URL(string: fullUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
        let request = NSMutableURLRequest(url:requestUrl!)
        request.httpMethod = "POST"
        
        // Create session configuration (for authentication)
        let config = URLSessionConfiguration.default
        if(chooser_auth_or_no_auth.selectedSegmentIndex==0){
            let userPasswordString = "\(tbUserName.text ?? ""):\(tbPassword.text ?? "")",
            userPasswordData = userPasswordString.data(using: String.Encoding.utf8),
            base64EncodedCredential = userPasswordData?.base64EncodedString(),
            authString = "Basic \(base64EncodedCredential ?? "none")"
            config.httpAdditionalHeaders = ["Authorization" : authString]
        }
        
        // Create session
        let session = URLSession(configuration: config)
        
        // Set up task for execution
        let task = session.dataTask(with: request as URLRequest) {
            (
            data, response, error) in
            
            guard let _:NSData = data as NSData?, let _:URLResponse = response, error == nil else {
                print("Error posting to Cloud.")
                return
            }
            
            if let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            {
                print(dataString)
            }
        }
        
        task.resume()
    }

    // --------------------------------------------------------------------------------------
    //                    ALL UDP LOWER LEVEL CODE
    // --------------------------------------------------------------------------------------
    
    fileprivate var _socket: GCDAsyncUdpSocket?
    fileprivate var socket: GCDAsyncUdpSocket? {
        get {
            if _socket == nil {
                _socket = getNewSocket()
            }
            return _socket
        }
        set {
            if _socket != nil {
                _socket?.close()
            }
            _socket = newValue
        }
    }
    
    fileprivate func getNewSocket() -> GCDAsyncUdpSocket? {
        
        // set port to CallerID.com port --> 3520
        let port = UInt16(3520)
        
        // Bind to CallerID.com port (3520)
        let sock = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        do {
            
            try sock.bind(toPort: port)
            try sock.enableBroadcast(true)
            
        } catch _ as NSError {
            
            return nil
            
        }
        return sock
    }
    
    fileprivate func startServer() {
        
        do {
            try socket?.beginReceiving()
        } catch _ as NSError {
            
            return
            
        }
        
    }
    
    fileprivate func stopServer(_ sender: AnyObject) {
        if socket != nil {
            socket?.pauseReceiving()
        }
        
    }
    
    // -------------------------------------------------------------------------
    // -------------------------------------------------------------------------
    //                     Receive data from a UDP broadcast
    // -------------------------------------------------------------------------
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        
        if let udpRecieved = NSString(data: data, encoding: String.Encoding.ascii.rawValue) {
            
            // ----------------------------------------------------------------
            // Keep track of previous 30 to have ablitiy of ignoring duplicate
            // packets - even if they are out of order, which can happen
            //-----------------------------------------------------------------
            let found = previousReceived[udpRecieved as String] != nil
            if(found){
                return
            }
            
            if(previousReceived.count>30){
                previousReceived[udpRecieved as String] = 0
                
                var removal_key = ""
                for key in previousReceived.keys{
                    removal_key = key
                    break
                }
                
                previousReceived.removeValue(forKey: removal_key)
                
            }
            else{
                previousReceived[udpRecieved as String] = 0
            }
            //-----------------------------------------------------------------
            
            // parse and handle udp data----------------------------------------------
            
            // declare used variables for matching
            var lineNumber = "n/a"
            var startOrEnd = "n/a"
            var ckSum = "n/a"
            var inboundOrOutbound = "n/a"
            var duration = "n/a"
            var callRing = "n/a"
            var callTime = "01/01 0:00:00"
            var phoneNumber = "n/a"
            var callerId = "n/a"
            var detailedType = "n/a"
            
            let callMatches = (udpRecieved as String).capturedGroups(withRegex: callRecordPattern)
            
            if(callMatches.count>0){
                
                lineNumber = callMatches[0]
                inboundOrOutbound = callMatches[1]
                startOrEnd = callMatches[2]
                duration = callMatches[3]
                ckSum = callMatches[4]
                callRing = callMatches[5] + callMatches[6]
                callTime = callMatches[7]
                phoneNumber = callMatches[8]
                callerId = callMatches[9]
                
                // Add to SQL
                insertIntoSql(line: lineNumber, time: callTime, phone: phoneNumber, name: callerId, io: inboundOrOutbound, se: startOrEnd, status: detailedType, duration: duration, ringNumber: callRing.getCharAtIndexAsString(i: 0), ringType: callRing.getCharAtIndexAsString(i: 1), checksum: ckSum)
                
                // Get URL to post to
                var postToThisUrl = ""
                if(chooser_supplied_or_built.selectedSegmentIndex==0){
                    postToThisUrl = tbSuppliedUrl.text!
                }
                else{
                    postToThisUrl = lbGeneratedUrl.text!
                }
                
                let ringT = callRing.getCharAtIndexAsString(i: 0)
                let ringN = callRing.getCharAtIndexAsString(i: 1)
                
                // POST to Cloud
                if(chooser_deluxe_or_basic.selectedSegmentIndex==0){
                    
                    // If Basic Unit, only send Start records to the cloud
                    if(startOrEnd == "S"){
                        
                        post_url(urlPost: postToThisUrl, line: lineNumber, time: callTime, phone: phoneNumber, name: callerId, io: inboundOrOutbound, se: startOrEnd, status: detailedType, duration: duration, ringNumber: ringN, ringType: ringT)
                        
                    }
                    
                }
                else{
                    
                    // If Deluxe Unit - send all (detailed will be handled independently
                    post_url(urlPost: postToThisUrl, line: lineNumber, time: callTime, phone: phoneNumber, name: callerId, io: inboundOrOutbound, se: startOrEnd, status: detailedType, duration: duration, ringNumber: ringN, ringType: ringT)
                    
                }
                
                
                let textToLog = (udpRecieved as String).getCompleteMatch(regex: callRecordPattern)
                if(lineNumber != "n/a"){
                    
                    addToLog(text: textToLog as String)
                    
                }
                
            }
            
            let detailMatches = (udpRecieved as String).capturedGroups(withRegex: detailedPattern)
            
            if(detailMatches.count>0){
                
                // If detailed then check to see if box is a Deluxe unit and also that the detailed
                // user parameter variable is setup
                if(tbStatus.text != "" || chooser_deluxe_or_basic.selectedSegmentIndex==0){
                    
                    lineNumber = detailMatches[0]
                    detailedType = detailMatches[1]
                    callTime = detailMatches[2]
                    
                    // Get URL to post to
                    var postToThisUrl = ""
                    if(chooser_supplied_or_built.selectedSegmentIndex==0){
                        postToThisUrl = tbSuppliedUrl.text!
                    }
                    else{
                        postToThisUrl = lbGeneratedUrl.text!
                    }
                    
                    // Add to SQL
                    DBManager.shared.addToLog(dateTime: callTime, line: lineNumber, type: "", indicator: detailedType, dur: "", checksum: "", rings: "", num: "", name: "")
                    
                    // POST to Cloud
                    post_url(urlPost: postToThisUrl, line: lineNumber, time: callTime, phone: "", name: "", io: "", se: "", status: detailedType, duration: "", ringNumber: "", ringType: "")
                    
                }
                
                let textToLog = (udpRecieved as String).getCompleteMatch(regex: detailedPattern)
                if(lineNumber != "n/a"){
                 
                    addToLog(text: textToLog as String)
                    
                }
                
            }
            
            if(debugMode){
                
                if(callMatches.count<1 && detailMatches.count<1){
                    
                    totalPackets += 1
                    tbLine.text = "Total Packets: " + String(totalPackets)
                    
                    
                }
            }
            
        }
        
    }
    
    func clipboardContent() -> String?
    {
        return UIPasteboard.general.string
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension String {
    
    func getCharAtIndexAsString(i:Int)->String{
        let index = self.index(self.startIndex, offsetBy: i)
        return "\(self [index])"
    }
    
    func capturedGroups(withRegex pattern: String) -> [String] {
        var results = [String]()
        
        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return results
        }
        
        let matches = regex.matches(in: self, options: [], range: NSRange(location:0, length: self.characters.count))
        
        guard let match = matches.first else { return results }
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return results }
        
        for i in 1...lastRangeIndex {
            let capturedGroupIndex = match.rangeAt(i)
            let matchedString = (self as NSString).substring(with: capturedGroupIndex)
            results.append(matchedString)
        }
        
        return results
    }
    func getCompleteMatch(regex: String) -> String {
        
        do {
            let regex = try NSRegularExpression(pattern: regex, options: [])
            let nsString = self as NSString
            let results = regex.matches(in: self,
                                        options: [], range: NSMakeRange(0, nsString.length))
            let groups = results.map { nsString.substring(with: $0.range)}
            return groups[0]
            
        } catch let error as NSError {
            print("invalid regex: \(error.localizedDescription)")
            return ""
        }
    }
}
