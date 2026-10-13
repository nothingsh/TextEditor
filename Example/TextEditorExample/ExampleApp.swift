import SwiftUI

@main
struct ExampleApp: App {
    @StateObject private var draft = DraftStore()

    var body: some Scene {
        WindowGroup {
            EditorScreen(draft: draft)
        }
    }
}
