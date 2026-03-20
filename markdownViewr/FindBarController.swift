import Foundation
import AppKit

extension Notification.Name {
    static let findToggle = Notification.Name("findToggle")
    static let findNext = Notification.Name("findNext")
    static let findPrevious = Notification.Name("findPrevious")
}

struct FindStatus: Codable {
    var current: Int
    var total: Int
}

class FindBarController: ObservableObject {
    @Published var isVisible = false
    @Published var searchText = ""
    @Published var matchStatus: FindStatus?
    var onFindNext: (() -> Void)?
    var onFindPrevious: (() -> Void)?
    weak var window: NSWindow?

    func toggle() {
        isVisible.toggle()
        if !isVisible {
            searchText = ""
            matchStatus = nil
        }
    }

    func show() {
        isVisible = true
    }

    func hide() {
        isVisible = false
        searchText = ""
        matchStatus = nil
    }

    func findNext() {
        onFindNext?()
    }

    func findPrevious() {
        onFindPrevious?()
    }
}
