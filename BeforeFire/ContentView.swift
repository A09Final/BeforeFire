//
//  ContentView.swift
//  BeforeFire
//
//  Created by Ibnu Taufick Ahraza on 10/22/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            MonitorView(viewModel: .mock)
        }
    }
}

#Preview {
    ContentView()
}
