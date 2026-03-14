import WidgetKit
import SwiftUI

@main
struct SessionLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOSApplicationExtension 16.1, *) {
      SessionLiveActivityWidget()
    }
  }
}
