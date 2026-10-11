// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// The system share sheet over whatever is on screen, for files that are ready only after some work
/// ShareLink would have the sheet wait for the file while it opens
@MainActor
enum ShareSheet {
    static func present(_ items: [Any]) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        // The about page sits in the settings sheet, present above it
        while let presented = top.presentedViewController { top = presented }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // iPad shows the sheet as a popover, centered without an arrow
        if let popover = controller.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(controller, animated: true)
    }
}
