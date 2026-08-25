import SwiftUI
import MapKit

struct MainView: View {
    @StateObject private var vm = MainViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // 1. Map Canvas mit Route-Overlay & User Location
                MapReader { proxy in
                    Map(position: $vm.cameraPosition) {
                        UserAnnotation()
                        
                        if let route = vm.recordingRouteOverlay {
                            MapPolyline(route)
                                .stroke(.blue.opacity(0.82), lineWidth: 4)
                        }
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                // 2. Floating Action Controls (OBS & Recording)
                VStack(alignment: .trailing, spacing: 16) {
                    if vm.showOpenBikeSensorButton {
                        NavigationLink(destination: OBSConfigView()) {
                            Image(systemName: "sensor.tag.radiowaves.forward")
                                .font(.title3)
                                .foregroundColor(.primary)
                                .frame(width: 46, height: 46)
                                .background(.regularMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
                        }
                    }
                    
                    HStack {
                        Spacer()
                        // Central Record Button (Glass UI)
                        Button(action: vm.toggleRecording) {
                            VStack(spacing: 4) {
                                Text(vm.isRecording ? "Stop" : "Start Ride")
                                    .font(.headline)
                                
                                if let subtitle = vm.recordingStatusText {
                                    Text(subtitle)
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial, in: Capsule())
                            .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
                        }
                        .accentColor(vm.isRecording ? .red : .accentColor)
                        Spacer()
                    }
                }
                .padding(.bottom, 28)
                .padding(.trailing, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                    .disabled(vm.isRecording)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: MyTripsView(preselectedTrip: vm.recordedTrip)) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.primary)
                    }
                    .disabled(vm.isRecording)
                }
            }
            // 3. Modale Dialoge (HowTo & Region Selection)
            .alert("How To", isPresented: $vm.showHowToAlert) {
                Button("OK") { vm.confirmHowTo() }
                Button("Cancel", role: .cancel) { vm.skipHowTo() }
            } message: {
                Text("Would you like to view the User Manual now?\n\nIf not, you may access it via Settings/How To later")
            }
            .alert("Please choose a Region", isPresented: $vm.showRegionAlert) {
                Button("Yes") { vm.openRegionSettings() }
                Button("Later", role: .cancel) {}
                Button("Don't show this again") { vm.suppressRegionMessage() }
            } message: {
                Text(vm.regionAlertMessage)
            }
            .navigationDestination(isPresented: $vm.navigateToTrips) {
                MyTripsView(preselectedTrip: vm.recordedTrip)
            }
        }
    }
}