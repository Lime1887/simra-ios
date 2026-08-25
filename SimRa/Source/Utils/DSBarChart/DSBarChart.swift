//
//  DSBarChart.swift
//  SimRa
//
//  Created by Emil Pauls on 29.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


//
//  DSBarChart.swift
//  SimRa
//
//  Modern SwiftUI replacement for the legacy DSBarChart.
//

import SwiftUI

// MARK: - DSBarChart

struct DSBarChart: View {

    // MARK: Input

    let references: [String]
    let values: [Double]

    /// The color used for the labels.
    let labelColor: Color

    /// Optional maximum value.
    ///
    /// If nil, the maximum is calculated automatically
    /// from the supplied values.
    let maximumValue: Double?

    // MARK: Configuration

    private let barSpacing: CGFloat = 6
    private let chartHeight: CGFloat = 180

    // MARK: Initialization

    init(
        references: [String],
        values: [Double],
        color: Color = .accentColor,
        maximumValue: Double? = nil
    ) {
        self.references = references
        self.values = values
        self.labelColor = color
        self.maximumValue = maximumValue
    }

    // MARK: Body

    var body: some View {

        Group {

            if values.isEmpty {

                ContentUnavailableView(
                    "Keine Daten",
                    systemImage: "chart.bar",
                    description: Text(
                        "Für diese Darstellung sind noch keine Werte vorhanden."
                    )
                )

            } else {

                chart
            }
        }
        .frame(
            maxWidth: .infinity
        )
    }

    // MARK: Chart

    private var chart: some View {

        GeometryReader { geometry in

            let count = min(
                references.count,
                values.count
            )

            let availableWidth =
                geometry.size.width

            let totalSpacing =
                CGFloat(max(count - 1, 0))
                * barSpacing

            let barWidth =
                max(
                    (
                        availableWidth
                        - totalSpacing
                    )
                    / CGFloat(max(count, 1)),
                    1
                )

            HStack(
                alignment: .bottom,
                spacing: barSpacing
            ) {

                ForEach(
                    0..<count,
                    id: \.self
                ) { index in

                    bar(
                        index: index,
                        width: barWidth,
                        height: geometry.size.height
                    )
                }
            }
        }
        .frame(
            height: chartHeight
        )
        .accessibilityElement(
            children: .contain
        )
    }

    // MARK: Bar

    private func bar(
        index: Int,
        width: CGFloat,
        height: CGFloat
    ) -> some View {

        let value =
            max(
                values[index],
                0
            )

        let maximum =
            resolvedMaximum

        let ratio =
            maximum > 0
            ? min(
                max(
                    value / maximum,
                    0
                ),
                1
            )
            : 0

        let barHeight =
            max(
                CGFloat(ratio)
                * max(
                    height - 28,
                    1
                ),
                value > 0 ? 1 : 0
            )

        VStack(
            alignment: .center,
            spacing: 6
        ) {

            Spacer(
                minLength: 0
            )

            RoundedRectangle(
                cornerRadius: 5,
                style: .continuous
            )
            .fill(
                barColor(
                    ratio: ratio
                )
            )
            .frame(
                width: width,
                height: barHeight
            )
            .animation(
                .smooth(
                    duration: 0.35
                ),
                value: value
            )

            Text(
                references[index]
            )
            .font(
                .caption2
            )
            .foregroundStyle(
                labelColor
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(
                width: width
            )
        }
        .frame(
            width: width,
            height: height
        )
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            references[index]
        )
        .accessibilityValue(
            formattedValue(value)
        )
    }

    // MARK: Maximum

    private var resolvedMaximum: Double {

        if let maximumValue,
           maximumValue > 0 {
            return maximumValue
        }

        return values
            .map {
                max($0, 0)
            }
            .max() ?? 0
    }

    // MARK: Bar Color

    private func barColor(
        ratio: Double
    ) -> Color {

        let clampedRatio =
            min(
                max(ratio, 0),
                1
            )

        return Color(
            hue:
                (1.0 - clampedRatio)
                * 0.33,
            saturation: 0.82,
            brightness: 0.88
        )
    }

    // MARK: Accessibility

    private func formattedValue(
        _ value: Double
    ) -> String {

        if value.rounded() == value {
            return String(
                Int(value)
            )
        }

        return String(
            format: "%.1f",
            value
        )
    }
}

// MARK: - Convenience Initializer

extension DSBarChart {

    init(
        references: [String],
        values: [Int],
        color: Color = .accentColor,
        maximumValue: Double? = nil
    ) {
        self.init(
            references: references,
            values: values.map(Double.init),
            color: color,
            maximumValue: maximumValue
        )
    }

    init(
        references: [String],
        values: [Float],
        color: Color = .accentColor,
        maximumValue: Double? = nil
    ) {
        self.init(
            references: references,
            values: values.map(Double.init),
            color: color,
            maximumValue: maximumValue
        )
    }
}

// MARK: - Preview

#Preview("SimRa Bar Chart") {

    DSBarChart(
        references: [
            "Mo",
            "Di",
            "Mi",
            "Do",
            "Fr",
            "Sa",
            "So"
        ],
        values: [
            12,
            24,
            18,
            31,
            27,
            42,
            36
        ]
    )
    .padding()
}