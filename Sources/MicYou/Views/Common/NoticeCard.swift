// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// A dismissible message, for errors and one-off notices such as the Opus fallback or a new release
struct NoticeCard: View {
    enum Kind { case info, error }

    var title: String?
    let text: String
    let kind: Kind
    /// A follow-up such as opening the release page
    var action: (title: String, perform: () -> Void)?
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind == .error ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundStyle(tint)
                }
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action.title, action: action.perform)
                        .buttonStyle(.borderless)
                        .fontWeight(.semibold)
                        .tint(tint)
                        .padding(.top, 2)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    // A full size touch target that does not grow the card
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .padding(-12)
            .foregroundStyle(.secondary)
            .buttonStyle(.borderless)
            .accessibilityLabel(L10n.Common.dismiss)
        }
        .padding(14)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private var tint: Color { kind == .error ? .red : .blue }
}
