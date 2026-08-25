import SwiftUI
import UIKit

// MARK: - Modern Record Action Button

public struct ModernRecordActionButton: View {

    public let isRecording: Bool
    public let title: String
    public let subtitle: String?
    public let action: () -> Void

    public init(
        isRecording: Bool,
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) {
        self.isRecording = isRecording
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    public var body: some View {

        Button(action: action) {

            VStack(
                alignment: .center,
                spacing: 3
            ) {

                // MARK: Title

                HStack(
                    alignment: .center,
                    spacing: 7
                ) {

                    Image(
                        systemName: isRecording
                            ? "stop.fill"
                            : "record.circle"
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        isRecording
                            ? .red
                            : .green
                    )

                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(
                            isRecording
                                ? .red
                                : .green
                        )
                        .lineLimit(1)
                }

                // MARK: Subtitle / Data

                if let subtitle,
                   !subtitle.isEmpty {

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .center
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
        }
        .recordButtonStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? "")
    }
}

// MARK: - Button Style

private extension View {

    @ViewBuilder
    func recordButtonStyle() -> some View {

        if #available(iOS 26.0, *) {

            self
                .buttonStyle(
                    .glass(
                        .clear
                            .interactive()
                    )
                )

        } else {

            self
                .buttonStyle(.bordered)
        }
    }
}

// MARK: - UIKit Bridge

//
// Übergangslösung für die schrittweise Migration
// von UIKit nach SwiftUI.
//

@objcMembers
public final class ModernRecordButtonHostController:
    UIViewController {

    private let hostingController:
        UIHostingController<ModernRecordActionButton>

    public init(
        recording: Bool,
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) {

        let rootView =
            ModernRecordActionButton(
                isRecording: recording,
                title: title,
                subtitle: subtitle,
                action: action
            )

        self.hostingController =
            UIHostingController(
                rootView: rootView
            )

        super.init(
            nibName: nil,
            bundle: nil
        )

        setupHostingController()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {

        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    @objc(
        updateRecordingWithRecording:title:subtitle:action:
    )
    public func updateRecording(
        recording: Bool,
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) {

        hostingController.rootView =
            ModernRecordActionButton(
                isRecording: recording,
                title: title,
                subtitle: subtitle,
                action: action
            )
    }

    private func setupHostingController() {

        view.backgroundColor = .clear
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)

        view.addSubview(
            hostingController.view
        )

        hostingController.view
            .translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([

            hostingController.view.leadingAnchor
                .constraint(
                    equalTo: view.leadingAnchor
                ),

            hostingController.view.trailingAnchor
                .constraint(
                    equalTo: view.trailingAnchor
                ),

            hostingController.view.topAnchor
                .constraint(
                    equalTo: view.topAnchor
                ),

            hostingController.view.bottomAnchor
                .constraint(
                    equalTo: view.bottomAnchor
                )
        ])

        hostingController.didMove(
            toParent: self
        )
    }
}
