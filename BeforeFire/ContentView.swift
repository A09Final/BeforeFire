//
//  ContentView.swift
//  BeforeFire
//
//  Created by Ibnu Taufick Ahraza on 10/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var alarmPreview = AlarmPreviewModel()

    var body: some View {
        NavigationStack {
            MonitorView(viewModel: .mock)
        }
        .environment(alarmPreview)
        .onOpenURL { alarmPreview.open($0) }
        .fullScreenCover(isPresented: $alarmPreview.isAlarmPresented) {
            AlarmView()
                .presentationBackground(.clear)
        }
    }
}

#Preview {
    ContentView()
}
