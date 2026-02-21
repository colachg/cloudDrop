import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var showSettings = false

    private var canUpload: Bool {
        !appState.selectedBucket.isEmpty && !appState.publicURLBase.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(isPresented: $showSettings)
            } else if !appState.isConfigured {
                onboardingView
            } else {
                mainView
            }
        }
        .overlay(alignment: .bottom) {
            toastOverlay
        }
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(.quaternary)
                VStack(spacing: 6) {
                    Text("Welcome to CloudDrop")
                        .font(.headline)
                    Text("Configure your R2 credentials\nto start uploading files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSettings = true
                    }
                } label: {
                    Text("Open Settings")
                        .frame(width: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            Spacer()
            Divider()
            HStack {
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Quit")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Main View

    private var mainView: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            uploadSection
            activeUploadsSection
            errorBanner
            tabBar
            Divider()
            tabContent
            Divider()
            footerBar
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text(appState.selectedBucket.isEmpty ? "No bucket" : appState.selectedBucket)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(appState.selectedBucket.isEmpty ? .tertiary : .primary)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings = true
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Upload Section

    private var uploadSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)

            if canUpload {
                Text("Click to upload")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Set up bucket & URL in Settings")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.02))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    Color.primary.opacity(0.1),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        }
        .contentShape(Rectangle())
        .onTapGesture { if canUpload { showFilePicker() } }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Active Uploads

    @ViewBuilder
    private var activeUploadsSection: some View {
        if !appState.uploadTasks.isEmpty {
            VStack(spacing: 6) {
                ForEach(appState.uploadTasks) { task in
                    VStack(spacing: 3) {
                        HStack(spacing: 6) {
                            Group {
                                if task.isComplete {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if task.error != nil {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                } else {
                                    ProgressView()
                                        .controlSize(.mini)
                                }
                            }
                            .font(.caption2)

                            Text(task.fileName)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            if !task.isComplete && task.error == nil {
                                Text("\(Int(task.progress * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }

                        if !task.isComplete && task.error == nil {
                            ProgressView(value: task.progress)
                                .progressViewStyle(.linear)
                                .tint(.accentColor)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        if let error = appState.uploadError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 4)
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        appState.uploadError = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.06))
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton("Recent", systemImage: "clock", tag: 0)
            tabButton("Files", systemImage: "folder", tag: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func tabButton(_ title: String, systemImage: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tag
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10))
                Text(title)
                    .font(.caption)
            }
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? .primary : .tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == 0 {
            recentList
        } else {
            bucketList
        }
    }

    // MARK: - Recent Uploads

    private var recentList: some View {
        Group {
            if appState.recentUploads.isEmpty {
                emptyState(icon: "clock", message: "No recent uploads")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(appState.recentUploads) { upload in
                            RecentUploadRow(upload: upload) {
                                appState.copyToClipboard(upload.url)
                                appState.showToast("URL copied!")
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Bucket List

    private var bucketList: some View {
        Group {
            if appState.isLoadingObjects && appState.s3Objects.isEmpty && appState.s3Folders.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if appState.s3Objects.isEmpty && appState.s3Folders.isEmpty {
                if appState.currentPrefix.isEmpty {
                    emptyState(icon: "folder", message: "No files")
                } else {
                    VStack(spacing: 0) {
                        bucketListHeader
                        emptyState(icon: "folder", message: "Empty folder")
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        bucketListHeader

                        ForEach(appState.s3Folders, id: \.self) { folder in
                            FolderRow(
                                name: folderDisplayName(folder),
                                onTap: { appState.enterFolder(folder) }
                            )
                        }

                        ForEach(appState.s3Objects) { object in
                            BucketFileRow(
                                displayName: fileDisplayName(object.key),
                                object: object,
                                onCopy: {
                                    if let r2 = appState.r2Service {
                                        let url = r2.publicURL(
                                            bucket: appState.selectedBucket,
                                            key: object.key,
                                            baseURL: appState.publicURLBase
                                        )
                                        appState.copyToClipboard(url)
                                        appState.showToast("URL copied!")
                                    }
                                },
                                onDelete: {
                                    appState.deleteObject(object)
                                }
                            )
                        }
                    }
                }
                .scrollIndicators(.never)
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            if appState.s3Objects.isEmpty && appState.s3Folders.isEmpty {
                appState.loadObjects()
            }
        }
    }

    private var bucketListHeader: some View {
        HStack {
            if !appState.currentPrefix.isEmpty {
                Button {
                    appState.goBack()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                        Text(folderDisplayName(appState.currentPrefix))
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            let count = appState.s3Folders.count + appState.s3Objects.count
            Text("\(count) items")
                .font(.caption2)
                .foregroundStyle(.quaternary)

            Button {
                appState.loadObjects()
            } label: {
                if appState.isLoadingObjects {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(appState.isLoadingObjects)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Display Name Helpers

    private func folderDisplayName(_ fullPrefix: String) -> String {
        var name = fullPrefix
        if name.hasPrefix(appState.currentPrefix) {
            name = String(name.dropFirst(appState.currentPrefix.count))
        }
        if name.hasSuffix("/") {
            name = String(name.dropLast())
        }
        return name
    }

    private func fileDisplayName(_ key: String) -> String {
        if key.hasPrefix(appState.currentPrefix) {
            return String(key.dropFirst(appState.currentPrefix.count))
        }
        return key
    }

    // MARK: - Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 24, weight: .thin))
                .foregroundStyle(.quaternary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = appState.toastMessage {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text(message)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThickMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.3), value: appState.toastMessage)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            if !appState.recentUploads.isEmpty {
                Button("Clear History") {
                    appState.clearRecentUploads()
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Quit")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    private func showFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.item]
        panel.level = .floating

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            appState.uploadFiles(panel.urls)
        }
    }


}

// MARK: - Folder Row

private struct FolderRow: View {
    let name: String
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 11))
                .foregroundStyle(.blue)
                .frame(width: 16)

            Text(name)
                .font(.system(size: 12))
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Recent Upload Row

private struct RecentUploadRow: View {
    let upload: RecentUpload
    let onCopy: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(upload.fileName)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(upload.date, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 4)
            Image(systemName: "doc.on.doc")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture(perform: onCopy)
        .help(upload.url)
    }
}

// MARK: - Bucket File Row

private struct BucketFileRow: View {
    let displayName: String
    let object: S3Object
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForFile(object.key))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(formatFileSize(object.size))
                    Text(object.lastModified, style: .relative)
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 4)

            if isHovered {
                HStack(spacing: 6) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy URL")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }

    private func iconForFile(_ key: String) -> String {
        let ext = (key as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "tiff", "ico":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "mp4", "mov", "avi":
            return "film"
        case "mp3", "wav", "aac":
            return "music.note"
        case "zip", "gz", "tar", "rar":
            return "archivebox"
        case "html", "css", "js", "ts", "json", "xml":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc"
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
