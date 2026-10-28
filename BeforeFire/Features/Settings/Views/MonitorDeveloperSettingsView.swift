import SwiftUI

struct MonitorDeveloperSettingsView: View {
    @Binding var isActionGuidanceVisible: Bool
    @Binding var previewCondition: MonitorPreviewCondition
    @State private var showPlacementGuideline = false
    
    var body: some View {
            Form {
                Section {
                    NavigationLink {
                        HubConnectionView()
                    } label: {
                        Label("Hub Connection", systemImage: "")
                        //If systemImage is deleted, it breaks
                        //PLS DONT DELETE
                    }
                    .accessibilityIdentifier("settings.hubConnection")

                    Button {
                        showPlacementGuideline = true
                    } label: {
                        HStack {
                            Label("Placement Guideline", systemImage: "")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("settings.placementGuideline")

                    NavigationLink {
                        EmergencyContactView()
                    } label: {
                        Label("Emergency Contact", systemImage: "")
                    }
                    .accessibilityIdentifier("settings.emergencyContact")
                } header: {
                    Text("General")
                }

                Section {
                    Toggle("Show action guidance", isOn: $isActionGuidanceVisible)
                        .accessibilityIdentifier("settings.actionGuidanceToggle")

                    if isActionGuidanceVisible {
                        Picker("Preview condition", selection: $previewCondition) {
                            ForEach(MonitorPreviewCondition.allCases) { condition in
                                Text(condition.rawValue).tag(condition)
                            }
                        }
                        .accessibilityIdentifier("settings.previewCondition")
                    }
                } header: {
                    Text("Developer Settings")
                } footer: {
                    Text("Preview the status and action text with mock readings. These settings reset when the app restarts.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .sheet(isPresented: $showPlacementGuideline) {   // this was missing
                PlacementGuidelineView()
            }
        }
    
    // MARK: - Placeholder destination screens
    
    struct HubConnectionView: View {
        var body: some View {
            Form {
                Section("Status") {
                    LabeledContent("Hub", value: "Not connected")
                }
                Section {
                    Button("Connect to Hub") {
                        // TODO: start pairing / connection flow
                    }
                    .accessibilityIdentifier("hub.connectButton")
                }
            }
            .navigationTitle("Hub Connection")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    struct EmergencyContactView: View {
        @State private var name = ""
        @State private var phone = ""
        
        var body: some View {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Phone number", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                } footer: {
                    Text("This person will be contacted in an emergency.")
                }
            }
            .navigationTitle("Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
