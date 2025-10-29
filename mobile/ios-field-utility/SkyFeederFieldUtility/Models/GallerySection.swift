import Foundation

struct GallerySection: Identifiable, Hashable {
    let id: UUID
    let title: String
    let captures: [Capture]

    init(title: String, captures: [Capture]) {
        self.id = UUID()
        self.title = title
        self.captures = captures
    }
}

extension Array where Element == Capture {
    func groupedByDay(calendar: Calendar = .current) -> [GallerySection] {
        let groups = Dictionary(grouping: self) { capture -> Date in
            calendar.startOfDay(for: capture.capturedAt)
        }
        return groups
            .map { date, captures in
                let formatted = GallerySection.dateFormatter.string(from: date)
                let sorted = captures.sorted { $0.capturedAt > $1.capturedAt }
                return GallerySection(title: formatted, captures: sorted)
            }
            .sorted { lhs, rhs in
                guard let lhsDate = GallerySection.dateFormatter.date(from: lhs.title),
                      let rhsDate = GallerySection.dateFormatter.date(from: rhs.title) else {
                    return lhs.title > rhs.title
                }
                return lhsDate > rhsDate
            }
    }
}

private extension GallerySection {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
}
