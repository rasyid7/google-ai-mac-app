# Spotlight Chat Bar

## Context

Chat Bar saat ini menampilkan WebView mini — embed web interface Google AI di panel kecil floating.

**Problem:** Terlalu berat untuk skenario "quick ask". User harus tunggu WebView load, tidak terasa native.

**Goal:** Ganti Chat Bar menjadi pure text input seperti Spotlight Search. User ketik query → tekan Enter → full desktop window terbuka langsung dengan hasil Google AI.

**Posisi:** Tetap bottom (mengikuti setting user: bottom-left / bottom-center / bottom-right).

---

## Approach: Parallel Load + Dynamic Endpoint Discovery

**Masalah hardcode URL param** seperti `udm=50`: bisa berubah kapan saja tanpa notice dari Google.

**Solusi:** Saat Chat Bar muncul, langsung load `google.com/ai` di background (WebView tidak visible). Google akan redirect ke endpoint yang benar. Endpoint redirect ini kita simpan sebagai `endpointURL`. Saat user selesai ketik dan tekan Enter, endpoint sudah diketahui — tinggal append `&q=QUERY`.

```
Keyboard Shortcut pressed
       │
       ├─── [UI] Tampilkan Chat Bar (text input)
       │
       └─── [Background] webViewModel.refreshEndpoint()
                 │
                 └─ load google.com/ai → follow redirect
                         │
                         └─ URL settle di www.google.com/search?udm=XX&...
                                 │
                                 └─ simpan sebagai endpointURL ✓

User sedang ketik... (1-3 detik = waktu cukup untuk load)

User tekan Enter
       │
       ├─ endpointURL sudah ada → load endpointURL + &q=QUERY → expandToMainWindow
       │
       └─ endpointURL belum ada (user sangat cepat) → simpan pendingQuery
                 │
                 └─ saat URL observer settle → auto-fire navigate + expandToMainWindow
```

**Keuntungan:**
- Tidak hardcode `udm=50` atau param lain — Google ubah parameter → kita otomatis ikut
- Tidak ada delay di sisi user (parallel loading)
- Fallback built-in untuk user yang sangat cepat mengetik
- Stable entry point: `google.com/ai` tidak akan dihapus Google

---

## Files to Modify

### 1. `WebKit/WebViewModel.swift` — Endpoint Discovery

**Tambah properties:**
```swift
private(set) var endpointURL: URL? = nil   // discovered from redirect
var pendingQuery: String? = nil            // set jika user submit sebelum endpoint ready
```

**Tambah method `refreshEndpoint()`:**
```swift
func refreshEndpoint() {
    endpointURL = nil
    loadHome()  // load google.com/ai → trigger redirect discovery
}
```

**Update URL observer** — tangkap redirect endpoint:
```swift
urlObserver = wkWebView.observe(\.url, options: .new) { [weak self] webView, _ in
    DispatchQueue.main.async {
        guard let self, let currentURL = webView.url,
              let host = currentURL.host, host.hasSuffix("google.com") else { return }

        // Simpan sebagai endpoint jika bukan query result (tidak ada param "q")
        let queryItems = URLComponents(url: currentURL, resolvingAgainstBaseURL: false)?.queryItems
        let hasQueryParam = queryItems?.contains { $0.name == "q" } == true
        if !hasQueryParam {
            self.endpointURL = currentURL
            // Jika ada pending query, fire sekarang
            if let query = self.pendingQuery {
                self.pendingQuery = nil
                self.loadQuery(query)
            }
        }

        // existing isAtHome logic...
        let isHomeURL = host == Self.googleAIHost || host == "www.\(Self.googleAIHost)"
        if isHomeURL {
            self.isAtHome = true
            self.canGoBack = false
        } else {
            self.isAtHome = false
            self.canGoBack = webView.canGoBack
        }
    }
}
```

**Tambah method `loadQuery(_ query: String)`:**
```swift
func loadQuery(_ query: String) {
    guard var components = endpointURL.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) else {
        // Endpoint belum ready, simpan sebagai pending
        pendingQuery = query
        return
    }
    var items = components.queryItems ?? []
    items.removeAll { $0.name == "q" }
    items.append(URLQueryItem(name: "q", value: query))
    components.queryItems = items
    guard let url = components.url else { return }
    isAtHome = false
    wkWebView.load(URLRequest(url: url))
}
```

---

### 2. `Coordinators/AppCoordinator.swift` — submitQuery + showChatBar update

**Tambah method `submitQuery`:**
```swift
func submitQuery(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    webViewModel.loadQuery(trimmed)   // immediate jika endpoint ready, queue jika belum
    expandToMainWindow()
}
```

**Update `showChatBar()`:**
```swift
// Sebelum show panel: trigger background endpoint discovery
webViewModel.refreshEndpoint()

// Ganti ChatBarView init:
// Before:
ChatBarView(webView: webViewModel.wkWebView, onExpandToMain: { ... })
// After:
ChatBarView(onSubmit: { [weak self] text in
    self?.submitQuery(text)
})
```

---

### 3. `ChatBar/ChatBarView.swift` — Full Rewrite (Spotlight UI)

**Hapus:** `webView` param, `GoogleAIWebView` embed, expand button, drag region, `screenHeightOffset()`.

**Tambah:**
```swift
struct ChatBarView: View {
    let onSubmit: (String) -> Void
    @State private var queryText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Ask Google AI...", text: $queryText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isFocused)
                .onSubmit {
                    onSubmit(queryText)
                    queryText = ""
                }
            if !queryText.isEmpty {
                Button { queryText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { isFocused = true }
    }
}
```

**Visual:**
```
╭──────────────────────────────────────────────╮
│  🔍   Ask Google AI...                   ✕   │
╰──────────────────────────────────────────────╯
```

---

### 4. `ChatBar/ChatBarPanel.swift` — Simplify

**Hapus:**
- `startConversationTracking()` / `stopConversationTracking()` / timer
- `checkAndAdjustSize()` — auto-expansion
- `focusInput()` — JS DOM focus
- Size persistence ke UserDefaults
- CMD+N keyboard shortcut

**Ubah ukuran:**
```swift
static let defaultSize = NSSize(width: 560, height: 60)
// minSize & maxSize = defaultSize (no expansion)
```

**Tetap keep:** ESC dismiss, corner radius, border, positioning, non-activating panel.

---

## Edge Cases

| Skenario | Behavior |
|----------|----------|
| User submit sebelum redirect selesai | `loadQuery` simpan `pendingQuery` → auto-fire saat URL observer settle |
| User submit query kosong / spasi saja | Guard di `submitQuery` — tidak trigger apapun |
| Google ubah redirect URL / params | `endpointURL` otomatis update karena discover dari redirect live |
| User buka Chat Bar berulang kali | `refreshEndpoint()` dipanggil tiap `showChatBar()` — endpoint fresh |

---

## Verification

1. Build Xcode — tidak ada compile error
2. Run app → tekan keyboard shortcut Chat Bar
3. Panel kecil muncul di bottom, TextField langsung focused
4. Ketik query pelan → Enter → main window muncul dengan Google AI results
5. Ketik query sangat cepat (< 1 detik) → Enter → pending query fires, window muncul
6. ESC di Chat Bar → panel dismiss
7. Setting posisi (bottom-left/center/right) masih berfungsi
8. Query kosong / spasi → Enter tidak trigger apa-apa
