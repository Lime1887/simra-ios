//
//  SettingsView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import SwiftUI
import MessageUI

// MARK: - Settings View

struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.openURL)
    private var openURL

    // MARK: - Constants

    private let minimumTripsToSend = 10

    // MARK: - State

    @State
    private var showDiagnosticAlert = false

    @State
    private var showRidesActionSheet = false

    @State
    private var showMailAlert = false

    @State
    private var showMailComposer = false

    @State
    private var showResultAlert = false

    @State
    private var resultAlertTitle = ""

    @State
    private var resultAlertMessage = ""

    @State
    private var allRidesSizeString = ""

    @State
    private var recentRidesSizeString = ""

    @State
    private var hasEnoughTripsForRecent = false

    // MARK: - Body

    var body: some View {
        List {

            // MARK: General

            Section {
                Button {
                    openLocalizedURL(
                        en: "https://www.digital-future.berlin/en/research/projects/simra/",
                        de: "https://www.digital-future.berlin/forschung/projekte/simra/"
                    )
                } label: {
                    Label(
                        NSLocalizedString(
                            "About",
                            comment: "About"
                        ),
                        systemImage: "info.circle"
                    )
                }

                Button {
                    openLocalizedURL(
                        en: "https://www.tu.berlin/en/3s/research/projects/simra-privacy-policy-statement",
                        de: "https://www.tu.berlin/3s/forschung/projekte/simra-datenschutzerklaerung"
                    )
                } label: {
                    Label(
                        NSLocalizedString(
                            "Privacy",
                            comment: "Privacy"
                        ),
                        systemImage: "hand.raised"
                    )
                }

                Button {
                    showHowTo()
                } label: {
                    Label(
                        NSLocalizedString(
                            "How To",
                            comment: "How To"
                        ),
                        systemImage: "questionmark.circle"
                    )
                }

                Button {
                    handleFeedbackAction()
                } label: {
                    Label(
                        NSLocalizedString(
                            "Feedback",
                            comment: "Feedback"
                        ),
                        systemImage: "envelope"
                    )
                }

                Button {
                    openLocalizedURL(
                        en: "https://www.tu.berlin/en/footer/site-credits",
                        de: "https://www.tu.berlin/footer/impressum"
                    )
                } label: {
                    Label(
                        NSLocalizedString(
                            "Imprint",
                            comment: "Imprint"
                        ),
                        systemImage: "building.columns"
                    )
                }
            }

            // MARK: User

            Section {
                NavigationLink {
                    ProfileView()
                } label: {
                    Label(
                        "Profil",
                        systemImage: "person.crop.circle"
                    )
                }

                NavigationLink {
                    TripSettingsView()
                } label: {
                    Label(
                        "Fahrt-Einstellungen",
                        systemImage: "slider.horizontal.3"
                    )
                }
            }

            // MARK: Diagnostics

            Section {
                Button {
                    showDiagnosticAlert = true
                } label: {
                    HStack {
                        Text(versionString)

                        Spacer()
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityLabel(
                    NSLocalizedString(
                        "App version",
                        comment:
                            "Accessibility label for app version"
                    )
                )
                .accessibilityHint(
                    NSLocalizedString(
                        "Tap to send diagnostic data to the SimRa team.",
                        comment:
                            "Accessibility hint for app version"
                    )
                )
            }
        }
        .navigationTitle(
            NSLocalizedString(
                "Settings",
                comment: "Settings"
            )
        )
        .navigationBarTitleDisplayMode(.inline)

        // MARK: Diagnostic Confirmation

        .alert(
            NSLocalizedString(
                "Send local app data to SimRa team",
                comment:
                    "Diagnostic upload title"
            ),
            isPresented: $showDiagnosticAlert
        ) {
            Button(
                NSLocalizedString(
                    "Cancel",
                    comment: "Cancel"
                ),
                role: .cancel
            ) {
                // Nothing to do.
            }

            Button(
                NSLocalizedString(
                    "Continue",
                    comment: "Continue"
                )
            ) {
                Utility.writeSimRaPrefs()
                prepareAndShowRidesActionSheet()
            }
        } message: {
            Text(
                NSLocalizedString(
                    "Attention! Only tap the Continue button if you were asked to do so by the SimRa team. By pressing the Upload button in the next step, you send your SimRa configuration to the SimRa team. You can also specify to upload the last 10 rides or all rides.",
                    comment:
                        "Diagnostic upload explanation"
                )
            )
        }

        // MARK: Ride Selection

        .confirmationDialog(
            NSLocalizedString(
                "Do you also want to send rides?",
                comment:
                    "Ride upload question"
            ),
            isPresented: $showRidesActionSheet,
            titleVisibility: .visible
        ) {
            Button(
                String(
                    format: "%@ (%@)",
                    NSLocalizedString(
                        "Yes, all",
                        comment:
                            "Upload all rides"
                    ),
                    allRidesSizeString
                )
            ) {
                sendZipToServer(
                    allTrips: true
                )
            }

            if hasEnoughTripsForRecent {
                Button(
                    String(
                        format: "%@ %d (%@)",
                        NSLocalizedString(
                            "Yes, the last",
                            comment:
                                "Upload recent rides"
                        ),
                        minimumTripsToSend,
                        recentRidesSizeString
                    )
                ) {
                    sendZipToServer(
                        allTrips: false
                    )
                }
            }

            Button(
                NSLocalizedString(
                    "No, don't send any rides",
                    comment:
                        "Don't upload rides"
                ),
                role: .cancel
            ) {
                // Nothing to do.
            }
        }

        // MARK: Mail Unavailable

        .alert(
            NSLocalizedString(
                "SimRa",
                comment: "SimRa"
            ),
            isPresented: $showMailAlert
        ) {
            Button(
                NSLocalizedString(
                    "OK",
                    comment: "OK"
                ),
                role: .cancel
            ) {
                // Nothing to do.
            }
        } message: {
            Text(
                NSLocalizedString(
                    "Configure your Email, please!",
                    comment:
                        "Mail configuration required"
                )
            )
        }

        // MARK: Upload Result

        .alert(
            resultAlertTitle,
            isPresented: $showResultAlert
        ) {
            Button(
                NSLocalizedString(
                    "OK",
                    comment: "OK"
                ),
                role: .cancel
            ) {
                // Nothing to do.
            }
        } message: {
            Text(resultAlertMessage)
        }

        // MARK: Mail Composer

        .sheet(
            isPresented: $showMailComposer
        ) {
            MailView()
        }
    }

    // MARK: - Version

    private var versionString: String {
        let info = Bundle.main.infoDictionary

        let name =
            info?["CFBundleName"] as? String
            ?? "SimRa"

        let version =
            info?["CFBundleVersion"] as? String
            ?? ""

        let language =
            Locale.current.language.languageCode?.identifier
            ?? ""

        return "\(name)-\(version)-\(language)"
    }

    // MARK: - How To

    private func showHowTo() {
        let language =
            Locale.current.language.languageCode?.identifier
            ?? "de"

        let urlString =
            language == "en"
            ? "https://simra-backend.3s-rg.de:4998/SimRa_Instructions_IOS.pdf"
            : "https://simra-backend.3s-rg.de:4998/SimRa_Anleitung_IOS.pdf"

        guard let url = URL(string: urlString) else {
            return
        }

        openURL(url)
    }

    // MARK: - Localized URL

    private func openLocalizedURL(
        en: String,
        de: String
    ) {
        let language =
            Locale.current.language.languageCode?.identifier
            ?? "de"

        let urlString =
            language == "en"
            ? en
            : de

        guard let url = URL(string: urlString) else {
            return
        }

        openURL(url)
    }

    // MARK: - Feedback

    private func handleFeedbackAction() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showMailAlert = true
        }
    }

    // MARK: - Ride Upload Preparation

    private func prepareAndShowRidesActionSheet() {
        let totalTrips =
            Trip
                .allStoredIdentifiers()
                .count

        allRidesSizeString =
            getTripsSize(
                allTrips: true
            )

        recentRidesSizeString =
            getTripsSize(
                allTrips: false
            )

        hasEnoughTripsForRecent =
            totalTrips >= minimumTripsToSend

        showRidesActionSheet = true
    }

    // MARK: - Trip Files

    private func tripFilePaths(
        allTrips: Bool
    ) -> [String] {
        let tripIdentifiers =
            Trip
                .allStoredIdentifiers()
                .sorted {
                    $0.compare($1) == .orderedAscending
                }

        guard !tripIdentifiers.isEmpty else {
            return []
        }

        let selectedIdentifiers: [NSNumber]

        if !allTrips &&
            tripIdentifiers.count > minimumTripsToSend {
            selectedIdentifiers =
                Array(
                    tripIdentifiers.suffix(
                        minimumTripsToSend
                    )
                )
        } else {
            selectedIdentifiers =
                tripIdentifiers
        }

        guard
            let docsPath =
                Utility.getDocumentDirectory()
        else {
            return []
        }

        let documentsDirectory =
            docsPath as NSString

        var paths: [String] = []

        paths.reserveCapacity(
            selectedIdentifiers.count * 2
        )

        for tripIdentifier in selectedIdentifiers {
            let index =
                tripIdentifier.intValue

            let tripPath =
                documentsDirectory
                    .appendingPathComponent(
                        "Trip-\(index).json"
                    )

            let tripInfoPath =
                documentsDirectory
                    .appendingPathComponent(
                        "TripInfo-\(index).json"
                    )

            paths.append(tripPath)
            paths.append(tripInfoPath)
        }

        return paths
    }

    // MARK: - Size

    private func getTripsSize(
        allTrips: Bool
    ) -> String {
        let paths =
            tripFilePaths(
                allTrips: allTrips
            )

        guard !paths.isEmpty else {
            return ByteCountFormatter.string(
                fromByteCount: 0,
                countStyle: .file
            )
        }

        let fileManager =
            FileManager.default

        var totalBytes: Int64 = 0

        for path in paths {
            guard
                let attributes =
                    try? fileManager.attributesOfItem(
                        atPath: path
                    ),
                let size =
                    attributes[.size] as? Int64
            else {
                continue
            }

            totalBytes += size
        }

        return ByteCountFormatter.string(
            fromByteCount: totalBytes,
            countStyle: .file
        )
    }

    // MARK: - Create ZIP

    private func createZipFile(
        allTrips: Bool
    ) -> String? {
        let fileManager =
            FileManager.default

        let temporaryDirectory =
            URL(
                fileURLWithPath:
                    NSTemporaryDirectory(),
                isDirectory: true
            )

        let zipURL =
            temporaryDirectory
                .appendingPathComponent(
                    "Logger.zip"
                )

        var paths =
            Utility.getAllDocumentsPrefLinks()

        paths.append(
            contentsOf:
                tripFilePaths(
                    allTrips: allTrips
                )
        )

        paths =
            paths.filter {
                fileManager.fileExists(
                    atPath: $0
                )
            }

        guard !paths.isEmpty else {
            return nil
        }

        do {
            if fileManager.fileExists(
                atPath: zipURL.path
            ) {
                try fileManager.removeItem(
                    at: zipURL
                )
            }
        } catch {
            print(
                "Failed to remove old Logger.zip:",
                error
            )

            return nil
        }

        let created =
            SimpleZipArchiver.createZipFile(
                atPath: zipURL.path,
                withFilesAtPaths: paths
            )

        return created
            ? zipURL.path
            : nil
    }

    // MARK: - Upload ZIP

    private func sendZipToServer(
        allTrips: Bool
    ) {
        guard
            let zipFilePath =
                createZipFile(
                    allTrips: allTrips
                )
        else {
            showUploadResult(
                success: false
            )
            return
        }

        guard
            let zipData =
                try? Data(
                    contentsOf:
                        URL(
                            fileURLWithPath:
                                zipFilePath
                        )
                ),
            !zipData.isEmpty
        else {
            showUploadResult(
                success: false
            )
            return
        }

        let apiPrefix =
            API.apiPrefix()

        let clientHash =
            UIDevice.current
                .identifierForVendor?
                .uuidString
            ?? "unknown"

        let baseURL =
            "\(apiPrefix)/debug"

        guard
            var components =
                URLComponents(
                    string: baseURL
                )
        else {
            showUploadResult(
                success: false
            )
            return
        }

        components.queryItems = [
            URLQueryItem(
                name: "clientHash",
                value: clientHash
            )
        ]

        guard
            let url =
                components.url
        else {
            showUploadResult(
                success: false
            )
            return
        }

        let boundary =
            "SimRa-\(UUID().uuidString)"

        var request =
            URLRequest(
                url: url
            )

        request.httpMethod = "POST"

        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField:
                "Content-Type"
        )

        var body =
            Data()

        let header =
            """
            --\(boundary)\r
            Content-Disposition: form-data; name="file"; filename="Logger.zip"\r
            Content-Type: application/zip\r
            \r
            """

        body.append(
            Data(
                header.utf8
            )
        )

        body.append(
            zipData
        )

        let footer =
            "\r\n--\(boundary)--\r\n"

        body.append(
            Data(
                footer.utf8
            )
        )

        request.httpBody =
            body

        URLSession.shared.dataTask(
            with: request
        ) { _, response, error in

            DispatchQueue.main.async {
                if error != nil {
                    showUploadResult(
                        success: false
                    )
                    return
                }

                guard
                    let httpResponse =
                        response as? HTTPURLResponse
                else {
                    showUploadResult(
                        success: false
                    )
                    return
                }

                showUploadResult(
                    success:
                        (200...299).contains(
                            httpResponse.statusCode
                        )
                )
            }
        }
        .resume()
    }

    // MARK: - Upload Result

    private func showUploadResult(
        success: Bool
    ) {
        resultAlertTitle =
            NSLocalizedString(
                "SimRa",
                comment: "SimRa"
            )

        resultAlertMessage =
            success
            ? NSLocalizedString(
                "Files uploaded successfully",
                comment:
                    "Upload succeeded"
            )
            : NSLocalizedString(
                "Something went wrong. Please try again later",
                comment:
                    "Upload failed"
            )

        showResultAlert = true
    }
}

// MARK: - Mail View

struct MailView: UIViewControllerRepresentable {

    @Environment(\.presentationMode)
    private var presentationMode

    final class Coordinator:
        NSObject,
        MFMailComposeViewControllerDelegate
    {
        @Binding
        var presentation:
            PresentationMode

        init(
            presentation:
                Binding<PresentationMode>
        ) {
            _presentation =
                presentation
        }

        func mailComposeController(
            _ controller:
                MFMailComposeViewController,
            didFinishWith result:
                MFMailComposeResult,
            error:
                Error?
        ) {
            presentation.dismiss()
        }
    }

    func makeCoordinator()
        -> Coordinator
    {
        Coordinator(
            presentation:
                presentationMode
        )
    }

    func makeUIViewController(
        context:
            Context
    ) -> MFMailComposeViewController {

        let viewController =
            MFMailComposeViewController()

        viewController.mailComposeDelegate =
            context.coordinator

        viewController.setToRecipients([
            "ask@mcc.tu-berlin.de"
        ])

        viewController.setSubject(
            NSLocalizedString(
                "Feedback SimRa",
                comment:
                    "Feedback email subject"
            )
        )

        viewController.setMessageBody(
            NSLocalizedString(
                "Dear SimRa Team",
                comment:
                    "Feedback email body"
            ),
            isHTML: false
        )

        return viewController
    }

    func updateUIViewController(
        _ uiViewController:
            MFMailComposeViewController,
        context:
            Context
    ) {
        // Nothing to update.
    }
}
