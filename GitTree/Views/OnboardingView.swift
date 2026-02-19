import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var scanner: GitScanner
    @State private var grantedPaths: [String] = []
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "tree")
                    .font(.system(size: 56))
                    .foregroundStyle(.green.gradient)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)

                Text("Welcome to GitGrove")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("See all your git worktrees in one place")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 32)

            // Permission card
            VStack(spacing: 16) {
                permissionCard(
                    icon: "folder.badge.gearshape",
                    title: "Allow access to your code folders",
                    description: "GitGrove needs to scan your repositories to find worktrees. Select the folders where you keep your git projects.",
                    granted: !grantedPaths.isEmpty
                )

                if !grantedPaths.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(grantedPaths, id: \.self) { path in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.body)
                                Text(path)
                                    .font(.body.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if grantedPaths.isEmpty {
                    Button(action: grantAccess) {
                        Label("Select Folders…", systemImage: "folder.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.green)
                } else {
                    Button(action: finish) {
                        Label("Get Started", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.green)

                    Button("Add more folders…", action: grantAccess)
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { isAnimating = true }
    }

    private func permissionCard(icon: String, title: String, description: String, granted: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(granted ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: granted ? "checkmark.circle.fill" : icon)
                    .font(.title2)
                    .foregroundColor(granted ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(granted ? Color.green.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func grantAccess() {
        settings.promptForFolderAccess()
        withAnimation(.easeInOut(duration: 0.3)) {
            grantedPaths = settings.scanPaths
        }
    }

    private func finish() {
        withAnimation {
            settings.hasGrantedAccess = true
        }
        Task { await scanner.scan() }
    }
}
