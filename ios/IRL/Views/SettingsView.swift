import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

struct SettingsView: View {

    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var screenTimeService: ScreenTimeService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("irl_theme") private var selectedTheme: AppTheme = .system
    @AppStorage("irl_show_pins") private var showPinsOnGlobe = true
    @State private var screenTimeLimit: Double = UserDefaults.standard.double(forKey: "irl_screen_limit") == 0 ? 60 : UserDefaults.standard.double(forKey: "irl_screen_limit")
    @State private var notificationsEnabled = true
    @State private var showDeleteConfirmation = false
    @State private var showDeleteFinalConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Appearance
                Section {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button {
                            selectedTheme = theme
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: theme.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(IRLColors.oceanBlue)
                                    .frame(width: 24)
                                Text(theme.rawValue)
                                    .foregroundStyle(IRLColors.primaryText)
                                Spacer()
                                if selectedTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(IRLColors.earthGreen)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Appearance")
                }

                // Wellbeing
                Section {
                    HStack {
                        Label("Screen Time Limit", systemImage: "hourglass")
                        Spacer()
                        Text("\(Int(screenTimeLimit)) min")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $screenTimeLimit, in: 5...120, step: 5)
                        .tint(IRLColors.oceanBlue)
                        .onChange(of: screenTimeLimit) { _, newVal in
                            UserDefaults.standard.set(newVal, forKey: "irl_screen_limit")
                        }
                } header: {
                    Text("Appearance")
                }

                // Location pins
                Section {
                    Toggle(isOn: $showPinsOnGlobe) {
                        Label("Show pins on your globe", systemImage: "mappin.circle.fill")
                    }
                    .tint(IRLColors.earthGreen)
                    Text("Show where you've shared moments as glowing pins on your profile Earth.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Your World")
                }

                // Wellbeing
                Section {
                    HStack {
                        Label("Screen Time Limit", systemImage: "hourglass")
                        Spacer()
                        Text("\(Int(screenTimeLimit)) min")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $screenTimeLimit, in: 5...120, step: 5)
                        .tint(IRLColors.oceanBlue)
                        .onChange(of: screenTimeLimit) { _, newVal in
                            UserDefaults.standard.set(newVal, forKey: "irl_screen_limit")
                        }
                } header: {
                    Text("Wellbeing")
                }

                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Push Notifications", systemImage: "bell.fill")
                    }
                    .tint(IRLColors.earthGreen)
                } header: {
                    Text("Notifications")
                }

                // Safety
                Section {
                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        Label("Blocked", systemImage: "person.crop.circle.badge.minus")
                    }
                } header: {
                    Text("Safety")
                }

                // Privacy
                Section {
                    Label("Your data is end-to-end encrypted", systemImage: "lock.fill")
                        .foregroundStyle(IRLColors.earthGreen)
                    Label("We never sell your data", systemImage: "hand.raised.fill")
                        .foregroundStyle(IRLColors.earthGreen)
                    Label("We never track your activity", systemImage: "eye.slash.fill")
                        .foregroundStyle(IRLColors.earthGreen)
                    Label("All content verified as real", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(IRLColors.earthGreen)
                } header: {
                    Text("Privacy Promise")
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Made with")
                        Spacer()
                        Text("love for the planet")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // Delete all data
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete All My Data")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        authService.signOut()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .alert("Are you sure?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    showDeleteFinalConfirmation = true
                }
            } message: {
                Text("This will permanently delete all your photos, videos, and account data.")
            }
            .alert("This cannot be undone.", isPresented: $showDeleteFinalConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Yes, Delete Everything", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("All your data will be permanently erased.")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(IRLColors.oceanBlue)
                }
            }
        }
    }

    private func deleteAllData() {
        // Clear all UserDefaults keys starting with "irl_"
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("irl_") {
            defaults.removeObject(forKey: key)
        }

        // Delete the media directory
        let mediaDir = PostStore.mediaDirectory
        try? FileManager.default.removeItem(at: mediaDir)

        // Sign out and dismiss
        authService.signOut()
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService())
        .environmentObject(ScreenTimeService())
}
