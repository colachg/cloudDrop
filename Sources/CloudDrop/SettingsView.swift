import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool

    @State private var accountId = ""
    @State private var accessKeyId = ""
    @State private var secretAccessKey = ""
    @State private var apiToken = ""
    @State private var isVerifying = false
    @State private var statusMessage = ""
    @State private var statusSuccess = false
    @State private var showSecretKey = false
    @State private var showApiToken = false
    @State private var credentialsExpanded = false
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if appState.isConfigured {
                        configuredBody
                    } else {
                        unconfiguredBody
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }

            Divider()
            footerBar
        }
        .onAppear { loadExisting() }
        .alert("Clear All Credentials?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearCredentials()
            }
        } message: {
            Text("This will remove all saved credentials and disconnect from Cloudflare R2. You can re-enter them at any time.")
        }
    }

    // MARK: - Configured State

    private var configuredBody: some View {
        Group {
            connectionStatusCard

            if !appState.buckets.isEmpty {
                storageGroupBox
            }

            credentialsGroupBox

            dangerZoneGroupBox
        }
    }

    // MARK: - Unconfigured State

    private var unconfiguredBody: some View {
        Group {
            onboardingHeader
            credentialsOnboardingSection
            verifyButton
            statusRow
            credentialHelpText
        }
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(statusSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.green.opacity(0.2), lineWidth: 1))
    }

    private var statusSummary: String {
        let bucket = appState.selectedBucket.isEmpty ? "No bucket" : appState.selectedBucket
        let domain = shortenedDomain
        if domain.isEmpty {
            return bucket
        }
        return "\(bucket) \u{00B7} \(domain)"
    }

    private var shortenedDomain: String {
        let base = appState.publicURLBase
        guard !base.isEmpty,
              let comps = URLComponents(string: base),
              let host = comps.host else {
            return ""
        }
        return host
    }

    // MARK: - Storage GroupBox

    private var storageGroupBox: some View {
        GroupBox("Storage") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Bucket")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: { appState.selectedBucket },
                            set: { appState.saveSelectedBucket($0) }
                        )) {
                            ForEach(appState.buckets, id: \.self) { bucket in
                                Text(bucket).tag(bucket)
                            }
                        }
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Folder")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Picker("", selection: Binding(
                            get: { appState.defaultUploadPrefix },
                            set: { appState.saveDefaultUploadPrefix($0) }
                        )) {
                            Text("/ (root)").tag("")
                            ForEach(appState.availableFolders, id: \.self) { folder in
                                Text(folder).tag(folder)
                            }
                        }
                        .labelsHidden()
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Custom Domain")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if appState.availableDomains.isEmpty {
                        TextField("https://pub-xxx.r2.dev", text: Binding(
                            get: { appState.publicURLBase },
                            set: { appState.savePublicURLBase($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    } else {
                        Picker("", selection: Binding(
                            get: { appState.publicURLBase },
                            set: { appState.savePublicURLBase($0) }
                        )) {
                            ForEach(appState.availableDomains, id: \.self) { domain in
                                Text(domain).tag(domain)
                            }
                        }
                        .labelsHidden()
                    }
                }
            }
        }
        .font(.caption)
    }

    // MARK: - Credentials GroupBox (Configured)

    private var credentialsGroupBox: some View {
        GroupBox {
            DisclosureGroup("Credentials", isExpanded: $credentialsExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    fieldRow("Access Key ID", text: $accessKeyId)
                    revealableFieldRow("Secret Access Key", text: $secretAccessKey, isRevealed: $showSecretKey)
                    revealableFieldRow("API Token", text: $apiToken, isRevealed: $showApiToken)
                    verifyButton
                    statusRow
                }
                .padding(.top, 8)
            }
            .font(.caption)
        }
    }

    // MARK: - Danger Zone GroupBox

    private var dangerZoneGroupBox: some View {
        GroupBox("Danger Zone") {
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Text("Clear All Credentials")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .font(.caption)
    }

    // MARK: - Onboarding (Unconfigured)

    private var onboardingHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 14))
                    .foregroundStyle(.blue)
                Text("Connect to Cloudflare R2")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Text("Enter your R2 API credentials to start uploading files.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    private var credentialsOnboardingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            fieldRow("Access Key ID", text: $accessKeyId, hint: "Identifies your R2 API token")
            revealableFieldRow("Secret Access Key", text: $secretAccessKey, isRevealed: $showSecretKey, hint: "Secret paired with your key")
            revealableFieldRow("API Token", text: $apiToken, isRevealed: $showApiToken, hint: "Used to resolve Account ID")
        }
    }

    private var credentialHelpText: some View {
        HStack(spacing: 4) {
            Image(systemName: "questionmark.circle")
                .font(.caption2)
            Text("Find these in Cloudflare: R2 > Overview > Manage R2 API Tokens")
                .font(.caption2)
        }
        .foregroundStyle(.tertiary)
        .padding(.top, 2)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Back")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Settings")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            // Invisible balance for centering
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                Text("Back")
                    .font(.caption)
            }
            .hidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Verify

    private var verifyButton: some View {
        HStack(spacing: 6) {
            Button {
                verifyAndSave()
            } label: {
                HStack(spacing: 6) {
                    if isVerifying {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    Text(isVerifying ? "Verifying..." : "Verify & Save")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(
                accessKeyId.isEmpty || secretAccessKey.isEmpty
                    || apiToken.isEmpty || isVerifying
            )

            // Match the eye toggle / spacer width in field rows
            Color.clear
                .frame(width: 20, height: 1)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        if !statusMessage.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: statusSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(statusSuccess ? .green : .red)
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
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

    // MARK: - Field Helpers

    private func fieldRow(_ label: String, text: Binding<String>, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .textContentType(.none)
                // Invisible spacer matching the eye toggle width
                Color.clear
                    .frame(width: 20, height: 1)
            }
            if let hint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func revealableFieldRow(_ label: String, text: Binding<String>, isRevealed: Binding<Bool>, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Group {
                    if isRevealed.wrappedValue {
                        TextField("", text: text)
                    } else {
                        SecureField("", text: text)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

                Button {
                    isRevealed.wrappedValue.toggle()
                } label: {
                    Image(systemName: isRevealed.wrappedValue ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .help(isRevealed.wrappedValue ? "Hide" : "Reveal")
            }
            if let hint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Actions

    private func loadExisting() {
        if let credentials = appState.loadCredentials() {
            accountId = credentials.accountId
            accessKeyId = credentials.accessKeyId
            secretAccessKey = credentials.secretAccessKey
            apiToken = credentials.apiToken
        }
    }

    private func verifyAndSave() {
        isVerifying = true
        statusMessage = ""

        Task {
            do {
                // Auto-resolve Account ID from API token
                let resolvedAccountId = try await R2Service.resolveAccountId(apiToken: apiToken)
                accountId = resolvedAccountId

                let credentials = R2Credentials(
                    accountId: resolvedAccountId,
                    accessKeyId: accessKeyId,
                    secretAccessKey: secretAccessKey,
                    apiToken: apiToken
                )

                let tempService = R2Service(credentials: credentials)
                let buckets = try await tempService.verifyCredentials()

                guard appState.saveCredentials(credentials) else {
                    statusMessage = "Failed to save credentials."
                    statusSuccess = false
                    isVerifying = false
                    return
                }

                appState.saveBuckets(buckets)
                if !buckets.isEmpty && appState.selectedBucket.isEmpty {
                    appState.saveSelectedBucket(buckets[0])
                }
                appState.loadConfiguration()

                statusMessage = "Connected! Found \(buckets.count) bucket(s)."
                statusSuccess = true

                // Auto-dismiss settings after successful first-time setup
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPresented = false
                }
            } catch {
                statusMessage = error.localizedDescription
                statusSuccess = false
            }
            isVerifying = false
        }
    }

    private func clearCredentials() {
        appState.resetConfiguration()
        accountId = ""
        accessKeyId = ""
        secretAccessKey = ""
        apiToken = ""
        statusMessage = ""
        statusSuccess = false
        showSecretKey = false
        showApiToken = false
    }
}
