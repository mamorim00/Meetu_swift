//
//  SelectedChatKey.swift
//  Meetu_databutton
//
//  Created by Marina Amorim on 1.6.2025.
//


// --- New file: NotificationKeys.swift

import SwiftUI

private struct SelectedChatKey: EnvironmentKey {
    static let defaultValue: Binding<String?> = .constant(nil)
}

extension EnvironmentValues {
    var selectedChatId: Binding<String?> {
        get { self[SelectedChatKey.self] }
        set { self[SelectedChatKey.self] = newValue }
    }
}
