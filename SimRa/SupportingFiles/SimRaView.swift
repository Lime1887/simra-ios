//
//  SimRaView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct SimRaView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "bicycle.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("SimRa")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Sicherheit im Radverkehr — TU Berlin")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    // Action for starting recording or navigation
                }) {
                    Text("Start Recording")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    SimRaView()
}