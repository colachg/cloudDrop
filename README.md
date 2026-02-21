# CloudDrop

A lightweight macOS menu bar app for uploading files to [Cloudflare R2](https://developers.cloudflare.com/r2/) storage.

## Features

- Lives in the menu bar — no Dock icon, always accessible
- Upload files via file picker
- Browse and manage files in your R2 buckets
- Copy public URLs to clipboard with one click
- Delete objects directly from the app
- Auto-resolves Account ID from API token
- Custom domain support
- Credentials stored locally with restricted file permissions

## Requirements

- macOS 15+
- Swift 6.2+
- [just](https://github.com/casey/just) (optional, for build commands)

## Build & Run

```sh
# Development build + run
just dev

# Release build + bundle into .app
just bundle

# Bundle and open
just run

# Install to /Applications
just install
```

Or build manually:

```sh
swift build -c release
```

## Setup

1. Launch CloudDrop — it appears in the menu bar
2. Open Settings and enter your Cloudflare R2 credentials:
   - **Access Key ID**
   - **Secret Access Key**
   - **API Token**
3. Click **Verify & Save** — the app auto-resolves your Account ID and lists available buckets
4. Select a bucket and custom domain, then start uploading

Credentials can be found in the Cloudflare dashboard under **R2 > Overview > Manage R2 API Tokens**.

## License

MIT
