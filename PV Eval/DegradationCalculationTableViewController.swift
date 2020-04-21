//
//  DegradationCalculationTableViewController.swift
//  PV Eval
//
//  Created by Aaron Kampmeier on 4/21/20.
//  Copyright © 2020 ASU EPICS Stardust. All rights reserved.
//

import UIKit

/// This class will take in a few inputs about the solar panel, profile it, and calculate its probable degradation.
/// Inputs:
/// - Model Number
/// - Rated Efficiency (or rated Pmax)
/// - Area of the Panel
/// - Measured Current
/// - Measured Voltage
class DegradationCalculationTableViewController: UITableViewController, UITextFieldDelegate {
    
    //private var inModelNumber, inRatedEff, inRatedPmax, inPanelArea, inCurrent, inVoltage: Double?

    private var textFieldsInputKeys = [UITextField:InputKey]()
    private var inputValues = [InputKey:String]()
    
    /// All of the inputs needed to compute the degradation
    fileprivate enum InputKey: String, CaseIterable {
        case inModelNumber = "Model Number"
        case inRatedEff = "Rated Efficiency (%)"
        case inPanelArea = "Panel Area (m²)"
        case inCurrent = "Measured Current (A)"
        case inVoltage = "Measured Voltage (V)"
        case inRatedPmax = "Rated Pmax (W)"
        
        //Rated Pmax does not need to be shown, it is only a backup if rated Eff is not there. This list is a cut-down list of only the inputs showing on the main table view.
        static let mainInputs: [InputKey] = {
            var inputs = InputKey.allCases
            inputs.removeAll(where: {$0 == .inRatedPmax})
            return inputs
        }()
        
        var associatedPanelSpecification: PVPanel.PanelSpecificationKey? {
            switch self {
            case .inRatedEff:
                return .ratedEfficiency
            case .inPanelArea:
                return .moduleArea
            case .inRatedPmax:
                return .pMax
            default:
                return nil
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
        tableView.allowsSelection = true
        
        tableView.keyboardDismissMode = .interactive
    }
    
    /// Records any new inputs from the table view
    @objc internal func inputValueChanged(sender: UITextField) {
        if let inputKey = textFieldsInputKeys[sender] {
            inputValues[inputKey] = sender.text ?? ""
        }
    }
    
    internal func generateReport() {
        //First create a PVPanel object for it
        var newPanel = PVPanel(panelId: UUID().uuidString, modelNumber: inputValues[InputKey.inModelNumber])
        
        //Record the specifications on it
        let specsArray = inputValues.compactMap { (arg0) -> (PVPanel.PanelSpecificationKey, Double)? in
            let (key, value) = arg0
            if let specKey = key.associatedPanelSpecification, let value = Double(value) {
                return (specKey, value)
            } else {
                return nil
            }
        }
        let specs = specsArray.reduce(into: [:], {$0[$1.0] = $1.1})
        
        newPanel.record(specifications: specs)
        
        //Record the test results
        if let recordedVoltage = inputValues[.inVoltage], let recordedCurrent = inputValues[.inCurrent], let voltage = Double(recordedVoltage), let current = Double(recordedCurrent) {
            let powerOutput = voltage * current
            newPanel.record(test: PVPanelTest(timestamp: Date(), powerOutput: powerOutput))
        }
        
        //Now generate a profile
        newPanel.generateProfile { (profile, error) in
            if let error = error {
                //Show error
                let alert = UIAlertController(title: "Error", message: "Error generating panel profile: \(error)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
            
            if let profile = profile, let degradation = profile.degradation {
                let alert = UIAlertController(title: "Panel Degradation", message: "We calculated an estimated degradation of \((degradation * 10000).rounded() / 100)%, meaning that the panel is operating at \(((1 - degradation) * 10000).rounded() / 100)% of what it originally was.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cool", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return InputKey.mainInputs.count + 1
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0..<InputKey.mainInputs.count:
            let cell = tableView.dequeueReusableCell(withIdentifier: "inputCell", for: indexPath)
            
            let label = cell.contentView.viewWithTag(1) as! UILabel
            let textField = cell.contentView.viewWithTag(2) as! UITextField
            let helpButton = cell.contentView.viewWithTag(3) as! UIButton
            
            let inputKey = InputKey.mainInputs[indexPath.row]
            
            //Set up the text field by setting all the settings
            if inputKey == .inModelNumber {
                textField.keyboardType = .default
            } else {
                textField.keyboardType = .decimalPad
            }
            
            label.text = inputKey.rawValue
            textField.text = inputValues[inputKey]?.description
            
            textFieldsInputKeys[textField] = inputKey
            textField.addTarget(self, action: #selector(inputValueChanged(sender:)), for: .allEditingEvents)
            
            return cell
        case InputKey.mainInputs.count:
            //The calculate button
            let cell = tableView.dequeueReusableCell(withIdentifier: "complete", for: indexPath)
            
            
            return cell
        default:
            assertionFailure("There shouldn't be this row on the calculate table view")
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        //Do the computations
        generateReport()
        
        //Deselect the calculate button
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        //Do not select any of the input rows, only the calculate button
        if indexPath.row < InputKey.mainInputs.count {
            return nil
        }
        
        return indexPath
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
