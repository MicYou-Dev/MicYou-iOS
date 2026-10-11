// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A short note under a setting that explains the current choice or warns about a combination
/// It sits next to what it is about and changes with the choice, unlike a section footer
struct SettingHint: View {
    enum Style { case info, warning }

    let text: String
    let systemImage: String
    var style: Style = .info
    /// A fix for a warning, such as turning the conflicting option off
    var action: (title: String, perform: () -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(style == .warning ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                .frame(minWidth: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    // Borderless so only the button reacts, not the whole row
                    Button(action.title, action: action.perform)
                        .buttonStyle(.borderless)
                        .fontWeight(.semibold)
                }
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: action == nil ? .combine : .contain)
    }
}
