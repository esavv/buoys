//
//  BuoyDataWidgetLiveActivity.swift
//  BuoyDataWidget
//
//  Created by Erik Savage on 1/23/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BuoyDataWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BuoyDataWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BuoyDataWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension BuoyDataWidgetAttributes {
    fileprivate static var preview: BuoyDataWidgetAttributes {
        BuoyDataWidgetAttributes(name: "World")
    }
}

extension BuoyDataWidgetAttributes.ContentState {
    fileprivate static var smiley: BuoyDataWidgetAttributes.ContentState {
        BuoyDataWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BuoyDataWidgetAttributes.ContentState {
         BuoyDataWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BuoyDataWidgetAttributes.preview) {
   BuoyDataWidgetLiveActivity()
} contentStates: {
    BuoyDataWidgetAttributes.ContentState.smiley
    BuoyDataWidgetAttributes.ContentState.starEyes
}
