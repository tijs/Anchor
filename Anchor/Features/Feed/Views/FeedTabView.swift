import SwiftUI
import AnchorKit

struct FeedTabView: View {
    @Environment(BlueskyService.self) private var blueskyService
    @State private var feedService = FeedService()

    var body: some View {
        VStack(spacing: 16) {
            if blueskyService.isAuthenticated {
                // Feed content
                Group {
                    if feedService.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading check-ins...")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = feedService.error {
                        // Show error message
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.title)

                            Text("Feed Unavailable")
                                .font(.headline)

                            Text(error.localizedDescription)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)

                            Button("Try Again") {
                                Task {
                                    await loadFeed()
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if feedService.posts.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.bubble")
                                .foregroundStyle(.secondary)
                                .font(.title)

                            Text("No check-ins found")
                                .font(.headline)

                            Text("No check-ins found in the global feed.")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                                .multilineTextAlignment(.center)

                            Button("Refresh") {
                                Task {
                                    await loadFeed()
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(feedService.posts, id: \.id) { post in
                                    FeedPostView(post: post)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .refreshable {
                    await loadFeed()
                }
                .task {
                    await loadFeed()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .foregroundStyle(.orange)
                        .font(.title)

                    Text("Sign in to see your feed")
                        .font(.headline)

                    Text("Connect your Bluesky account to see check-ins from people you follow.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .multilineTextAlignment(.center)

                    Text("Click the gear button to open Settings")
                        .foregroundStyle(.blue)
                        .font(.caption2)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func loadFeed() async {
        guard let credentials = blueskyService.credentials else { return }

        do {
            _ = try await feedService.fetchGlobalFeed(credentials: credentials)
        } catch {
            // Error is now handled by FeedService and displayed in UI
            // No need to print to console
        }
    }
}

struct FeedPostView: View {
    let post: FeedPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author info
            Button {
                openBlueskyProfile(handle: post.author.handle)
            } label: {
                HStack(spacing: 8) {
                    AsyncImage(url: post.author.avatar.flatMap(URL.init)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(.secondary)
                            .overlay {
                                Text(String(post.author.handle.prefix(1).uppercased()))
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.author.displayName ?? post.author.handle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        Text("@\(post.author.handle)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(post.record.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Check-in content
            VStack(alignment: .leading, spacing: 4) {
                Text(.init(post.record.formattedText))
                    .font(.caption)
                
                // Show location info if available from checkin record
                if let checkinRecord = post.checkinRecord,
                   let locations = checkinRecord.locations,
                   !locations.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                        
                        Text(formatLocationInfo(locations))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func openBlueskyProfile(handle: String) {
        if let url = URL(string: "https://bsky.app/profile/\(handle)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func formatLocationInfo(_ locations: [LocationItem]) -> String {
        for location in locations {
            switch location {
            case .address(let address):
                var components: [String] = []
                if let name = address.name {
                    components.append(name)
                }
                if let locality = address.locality {
                    components.append(locality)
                }
                if !components.isEmpty {
                    return components.joined(separator: ", ")
                }
            case .geo(let geo):
                return "📍 \(geo.latitude), \(geo.longitude)"
            }
        }
        return "📍 Location"
    }
}

#Preview {
    FeedTabView()
        .environment(BlueskyService(storage: InMemoryCredentialsStorage()))
}
