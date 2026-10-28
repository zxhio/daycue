import SwiftUI

struct MainWindowView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Development"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("DayCue")
                .font(.largeTitle.weight(.semibold))

            Text("Version \(version)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(width: 360, height: 240)
        .accessibilityIdentifier("daycue.main-window")
    }
}
