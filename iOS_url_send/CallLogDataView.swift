import UIKit

class CallLogDataView: UITableView, UITableViewDataSource, UITableViewDelegate {
    
    var logData:[String] = []
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = UITableViewCell()
        
        cell.textLabel?.text = logData[indexPath.row]
        cell.textLabel?.font = UIFont(name:"Courier", size:16)
        
        return cell
        
    }
    
    public func addToLog(data:String) -> Bool{
        
        if(logData.count>0){
            if(logData[logData.count-1]==data){
                return false
            }
        }
        logData.append(data)
        
        return true
        
    }
    
    public func getLogDataCount() -> Int{
        return logData.count
    }
    
    public func clear(){
        logData = []
    }
    
}
