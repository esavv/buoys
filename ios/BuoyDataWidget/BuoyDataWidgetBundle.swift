//
//  BuoyDataWidgetBundle.swift
//  BuoyDataWidget
//
//  Created by Erik Savage on 1/23/25.
//

import WidgetKit
import SwiftUI

@main
struct BuoyDataWidgetBundle: WidgetBundle {
    var body: some Widget {
        BuoyDataWidget()
        BuoyDataWidgetControl()
        BuoyDataWidgetLiveActivity()
    }
}
