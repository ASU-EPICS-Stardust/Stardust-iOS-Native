//
//  PVPanelProfile.swift
//  PV Eval
//
//  Created by Aaron Kampmeier on 4/21/20.
//  Copyright © 2020 ASU EPICS Stardust. All rights reserved.
//

import Foundation

/// A struct representing all information about a monitored PV panel
internal struct PVPanel {
    internal let panelId: String
    internal let modelNumber: String?
    
    internal enum PanelSpecificationKey: String, CaseIterable {
        case ratedEfficiency = "Rated Efficiency (%)"
        case moduleArea = "Panel Area (m²)"
        case pMax = "Rated Pmax (W)"
        case tempCoeffPmax = "Pmax Temp. Coefficient (%/°C)"
        case openCircuitVoltage = "Voc"
        case shortCircuitCurrent = "Isc"
    }
    internal private(set) var specifications = [PanelSpecificationKey:Double]()
    
    internal private(set) var recordedTests = [PVPanelTest]()
    internal private(set) var recordedProfiles = [PVPanelProfile]()
    
    init(panelId: String, modelNumber: String?) {
        self.panelId = panelId
        self.modelNumber = modelNumber
    }
    
    internal mutating func record(test: PVPanelTest) {
        self.recordedTests.append(test)
    }
    
    internal mutating func record(specifications: [PanelSpecificationKey:Double]) {
        self.specifications.merge(specifications) {(_,new) in return new}
    }
    
    internal mutating func generateProfile(completion completionHandler: (PVPanelProfile?, Error?) -> Void) {
        PVPanelProfiler.generateProfile(forPanel: self) { (profile, error) in
            //TODO: Remake this using Combine
            if let profile = profile {
                recordedProfiles.append(profile)
            }
            
            completionHandler(profile, error)
        }
    }
}

/// Represents a test of a panel and the measured values
internal struct PVPanelTest {
    internal let timestamp: Date
    internal let powerOutput: Double
}

/// A report predicting degradation, lifespan, and worth of a PV panel.
internal struct PVPanelProfile {
    internal let panelId: String
    internal let degradation: Double?
    internal let generatedOn: Date
    
    init(forPanel panel: PVPanel, degradation: Double?) {
        self.panelId = panel.panelId
        self.generatedOn = Date()
        self.degradation = degradation
    }
}

fileprivate struct PVPanelProfiler {
    static fileprivate func generateProfile(forPanel panel: PVPanel, completionHandler: (PVPanelProfile?, Error?) -> Void) {
        //Generate the profile report
        var profile: PVPanelProfile?
        var error: PVPanelProfilerError?
        
        //Calculate predicted degradation
        if let lastTest = panel.recordedTests.last, let panelArea = panel.specifications[.moduleArea] {
            var ratedEff = panel.specifications[.ratedEfficiency]
            if ratedEff == nil, let pMax = panel.specifications[.pMax] {
                ratedEff = pMax / (1000 * panelArea)
            }
            
            if let ratedEff = ratedEff {
                // Compute the degradation
                //TODO: Actually get irradiance data
                let irradiance: Double = 1000
                let degradation = 1 - (lastTest.powerOutput / ((ratedEff / 100) * irradiance * panelArea))
                profile = PVPanelProfile(forPanel: panel, degradation: degradation)
            } else {
                error = .insufficientData
            }
        } else {
            error = .insufficientData
        }
        
        completionHandler(profile, error)
    }
    
    enum PVPanelProfilerError: Error, CustomStringConvertible {
        case insufficientData
        
        var description: String {
            switch self {
            case .insufficientData:
                return "There was insufficient data about the solar panel to generate a profile."
            }
        }
    }
}
