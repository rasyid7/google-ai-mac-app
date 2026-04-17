//
//  ChatBarContent.swift
//  GeminiDesktop
//
//  Created by alexcding on 2025-12-13.
//

import SwiftUI

struct ChatBarView: View {
    let onSubmit: (String) -> Void
    @State private var queryText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ask Google AI...", text: $queryText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isFocused)
                .onSubmit {
                    onSubmit(queryText)
                    queryText = ""
                }
            if !queryText.isEmpty {
                Button { queryText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { isFocused = true }
    }
}
