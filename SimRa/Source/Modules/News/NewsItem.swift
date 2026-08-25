import SwiftUI

// MARK: - Datenmodell für News-Zeilen

struct NewsItem: Identifiable {
    let id = UUID()
    let text: String
    let isHighlighted: Bool
}

// MARK: - SwiftUI View

struct NewsView: View {
    @State private var newsItems: [NewsItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if newsItems.isEmpty {
                    Text("Keine Neuigkeiten vorhanden")
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                } else {
                    ForEach(newsItems) { item in
                        Text(item.text)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(item.isHighlighted ? .red : .primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Neuigkeiten")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadNews)
    }

    // Parst die Zeilen aus AppDelegate.news.newsLines exakt wie im alten NewsVC
    private func loadNews() {
        guard let ad = UIApplication.shared.delegate as? AppDelegate,
              let lines = ad.news?.newsLines as? [String] else { return }

        var parsedItems: [NewsItem] = []
        
        for line in lines {
            if line.hasPrefix("-") || line.hasPrefix("i") {
                let text = String(line.dropFirst())
                parsedItems.append(NewsItem(text: text, isHighlighted: false))
            } else if line.hasPrefix("*") {
                let text = String(line.dropFirst())
                parsedItems.append(NewsItem(text: text, isHighlighted: true))
            }
        }
        
        self.newsItems = parsedItems
    }
}