//
//  SimRaAnnotationView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


import SwiftUI

struct SimRaAnnotationView: View {
    var personImage: UIImage?
    var recording: Bool
    var speed: Double
    var course: Double
    var accx: Double
    var accy: Double
    var accz: Double
    var heading: Double

    private let size: CGFloat = 30.0

    var body: some View {
        ZStack {
            // 1. Hintergrund-Kreis
            Circle()
                .fill(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.5))

            // 2. Profilbild / Person-Bild (falls vorhanden)
            if let uiImage = personImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            }

            // 3. Tacho-Anzeige (Geschwindigkeit)
            if speed > 0 {
                let tachoMax: Double = 50.0 // km/h
                let progress = min((speed * 3.6) / tachoMax, 1.0)
                let startAngle = Angle.degrees(90 + 30)
                let endAngle = startAngle + Angle.degrees(360.0 * (5.0 / 6.0) * progress)

                TachoArcShape(startAngle: startAngle, endAngle: endAngle)
                    .fill(Color.red.opacity(0.5))
                
                TachoArcShape(startAngle: startAngle, endAngle: endAngle)
                    .stroke(Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.5), lineWidth: 1.0)
            }

            // 4. Äußerer Rahmen (Fence)
            Circle()
                .stroke(Color(red: 77/255, green: 97/255, blue: 137/255), lineWidth: 3.0)

            // 5. Kurs-Anzeige (Course)
            if course > 0 {
                let rad = (course - 90) * .pi / 180
                let courseWidth: CGFloat = 10.0
                let x = size / 2 + (size / 2) * cos(rad) - courseWidth / 2
                let y = size / 2 + (size / 2) * sin(rad) - courseWidth / 2

                Circle()
                    .fill(Color.blue)
                    .frame(width: courseWidth, height: courseWidth)
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1.0))
                    .position(x: x + courseWidth / 2, y: y + courseWidth / 2)
            }

            // 6. Beschleunigung (Accelerations)
            if accx != 0 || accy != 0 || accz != 0 {
                Ellipse()
                    .fill(Color.green.opacity(0.5))
                    .frame(width: max(0, abs(accx) * size / 2), height: max(0, abs(accx) * size / 2))
                    .overlay(Ellipse().stroke(Color.green, lineWidth: 2.0))
                    .position(x: size * 3 / 4, y: size * 3 / 4)

                Ellipse()
                    .fill(Color.red.opacity(0.5))
                    .frame(width: max(0, abs(accy) * size / 2), height: max(0, abs(accy) * size / 2))
                    .position(x: size * (1 - abs(accy) / 2), y: size * 3 / 4)

                Ellipse()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: max(0, abs(accz) * size / 2), height: max(0, abs(accz) * size / 2))
                    .position(x: size * (1 - abs(accz) / 4), y: size * (1 - abs(accz) / 2))
            }

            // 7. Aufnahme- / Stopp-Kontrollsymbol in der Mitte
            Group {
                if recording {
                    RoundedRectangle(cornerRadius: size / 16)
                        .frame(width: size / 2, height: size / 2)
                } else {
                    Circle()
                        .frame(width: size * 3 / 4, height: size * 3 / 4)
                }
            }
            .fill(Color.red.opacity(0.75))
            .overlay(
                Group {
                    if recording {
                        RoundedRectangle(cornerRadius: size / 16)
                            .stroke(Color.white, lineWidth: 1.0)
                            .frame(width: size / 2, height: size / 2)
                    } else {
                        Circle()
                            .stroke(Color.white, lineWidth: 1.0)
                            .frame(width: size * 3 / 4, height: size * 3 / 4)
                    }
                }
            )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// Hilfs-Shape für den Tacho-Bogen
struct TachoArcShape: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2

        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}