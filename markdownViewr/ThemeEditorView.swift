import SwiftUI

struct ThemeEditorView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var editingTheme: Theme?

    @State private var name: String
    @State private var colors: ThemeColors
    @State private var fonts: ThemeFonts
    @State private var sizes: ThemeSizes
    @State private var customCSS: String

    @State private var previewMarkdown: String = sampleMarkdown
    @State private var previewHTML: String = MarkdownDocument.convertToHTML(sampleMarkdown)
    @State private var usingCustomFile = false
    @State private var customFileName: String?

    @State private var showNameError = false
    @State private var nameErrorMessage = ""

    init(editingTheme: Theme? = nil) {
        self.editingTheme = editingTheme
        _name = State(initialValue: editingTheme?.name ?? "")
        _colors = State(initialValue: editingTheme?.colors ?? ThemeColors())
        _fonts = State(initialValue: editingTheme?.fonts ?? ThemeFonts())
        _sizes = State(initialValue: editingTheme?.sizes ?? ThemeSizes())
        _customCSS = State(initialValue: editingTheme?.customCSS ?? "")
    }

    private var currentTheme: Theme {
        Theme(name: name, colors: colors, fonts: fonts, sizes: sizes, customCSS: customCSS)
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetToolbar
            HSplitView {
                controlsPanel
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)

                previewPanel
                    .frame(minWidth: 400, idealWidth: 500)
            }
        }
        .frame(minWidth: 800, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
    }

    private var sheetToolbar: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    ThemeEditorWindowController.shared.close()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Text(editingTheme == nil ? "New Theme" : "Edit Theme")
                    .font(.headline)

                Spacer()

                Button("Save") {
                    saveTheme()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            Divider()
        }
    }

    private var controlsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                nameSection
                colorsSection
                fontsSection
                sizesSection
                cssSection
            }
            .padding(20)
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Name")
                .font(.headline)
            TextField("My Theme", text: $name)
                .textFieldStyle(.roundedBorder)
            if showNameError {
                Text(nameErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Colors")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                colorRow("Background", $colors.background)
                colorRow("Text", $colors.text)
                colorRow("H1", $colors.heading1)
                colorRow("H2", $colors.heading2)
                colorRow("H3", $colors.heading3)
                colorRow("H4", $colors.heading4)
                colorRow("H5", $colors.heading5)
                colorRow("H6", $colors.heading6)
                colorRow("Link", $colors.link)
                colorRow("Code BG", $colors.codeBackground)
                colorRow("Code Text", $colors.codeText)
                colorRow("Quote Border", $colors.blockquoteBorder)
                colorRow("Quote BG", $colors.blockquoteBackground)
                colorRow("Highlight BG", $colors.highlightBackground)
                colorRow("Highlight Text", $colors.highlightText)
            }
        }
    }

    private func colorRow(_ label: String, _ hex: Binding<String>) -> some View {
        HStack(spacing: 10) {
            ColorPicker("", selection: Binding(
                get: { Color(hex: hex.wrappedValue) ?? .gray },
                set: { hex.wrappedValue = $0.toHex() }
            ))
            .labelsHidden()
            .frame(width: 30)

            Text(label)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private static let bodyFonts = [
        "System",
        "Helvetica Neue",
        "Georgia",
        "Palatino",
        "Avenir",
        "Avenir Next",
        "Gill Sans",
        "Hoefler Text",
        "Charter",
        "Times New Roman",
        "Verdana",
        "Arial"
    ]

    private static let codeFonts = [
        "SF Mono",
        "Menlo",
        "Monaco",
        "Courier New",
        "Andale Mono",
        "Source Code Pro",
        "Fira Code",
        "JetBrains Mono"
    ]

    private static let customMarker = "Custom..."

    private var isCustomBodyFont: Bool {
        !Self.bodyFonts.contains(fonts.body) && fonts.body != Self.customMarker
    }

    private var isCustomHeadingFont: Bool {
        !Self.bodyFonts.contains(fonts.heading) && fonts.heading != Self.customMarker
    }

    private var isCustomCodeFont: Bool {
        !Self.codeFonts.contains(fonts.code) && fonts.code != Self.customMarker
    }

    @State private var customBodyFont: String = ""
    @State private var customHeadingFont: String = ""
    @State private var customCodeFont: String = ""

    private var fontsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fonts")
                .font(.headline)

            fontPicker(
                label: "Body",
                selection: $fonts.body,
                options: Self.bodyFonts,
                customValue: $customBodyFont,
                isCustom: isCustomBodyFont
            )

            fontPicker(
                label: "Heading",
                selection: $fonts.heading,
                options: Self.bodyFonts,
                customValue: $customHeadingFont,
                isCustom: isCustomHeadingFont
            )

            fontPicker(
                label: "Code",
                selection: $fonts.code,
                options: Self.codeFonts,
                customValue: $customCodeFont,
                isCustom: isCustomCodeFont
            )
        }
        .onAppear {
            if isCustomBodyFont { customBodyFont = fonts.body }
            if isCustomHeadingFont { customHeadingFont = fonts.heading }
            if isCustomCodeFont { customCodeFont = fonts.code }
        }
    }

    private func fontPicker(
        label: String,
        selection: Binding<String>,
        options: [String],
        customValue: Binding<String>,
        isCustom: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .frame(width: 50, alignment: .leading)
                Picker("", selection: Binding(
                    get: {
                        if options.contains(selection.wrappedValue) {
                            return selection.wrappedValue
                        }
                        return Self.customMarker
                    },
                    set: { newValue in
                        if newValue == Self.customMarker {
                            if !customValue.wrappedValue.isEmpty {
                                selection.wrappedValue = customValue.wrappedValue
                            } else {
                                selection.wrappedValue = Self.customMarker
                            }
                        } else {
                            selection.wrappedValue = newValue
                        }
                    }
                )) {
                    ForEach(options, id: \.self) { font in
                        Text(font).tag(font)
                    }
                    Divider()
                    Text("Custom...").tag(Self.customMarker)
                }
                .labelsHidden()
            }
            if isCustom || selection.wrappedValue == Self.customMarker {
                TextField("Font name", text: customValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .padding(.leading, 50)
                    .onChange(of: customValue.wrappedValue) { newValue in
                        if !newValue.isEmpty {
                            selection.wrappedValue = newValue
                        }
                    }
            }
        }
    }

    private var sizesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sizes")
                .font(.headline)

            sizeRow("Base", $sizes.baseFontSize, range: 10...24)
            sizeRow("H1", $sizes.h1Size, range: 16...48)
            sizeRow("H2", $sizes.h2Size, range: 14...40)
            sizeRow("H3", $sizes.h3Size, range: 12...36)
            sizeRow("H4", $sizes.h4Size, range: 12...32)
            sizeRow("H5", $sizes.h5Size, range: 10...28)
            sizeRow("H6", $sizes.h6Size, range: 10...24)
            sizeRow("Code", $sizes.codeFontSize, range: 8...20)
            sizeRow("Line H", $sizes.lineHeight, range: 1.0...3.0, step: 0.1)
        }
    }

    private func sizeRow(_ label: String, _ value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(step < 1 ? String(format: "%.1f", value.wrappedValue) : "\(Int(value.wrappedValue))")
                .font(.caption.monospacedDigit())
                .frame(width: 32, alignment: .trailing)
        }
    }

    @State private var showCSSHelp = false

    private var cssSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Custom CSS")
                    .font(.headline)
                Button {
                    showCSSHelp.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showCSSHelp, arrowEdge: .trailing) {
                    CSSHelpView()
                }
            }
            TextEditor(text: $customCSS)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 80, maxHeight: 120)
                .border(Color.secondary.opacity(0.3))
                .scrollContentBackground(.hidden)
        }
    }

    private var previewPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.headline)

                Spacer()

                if usingCustomFile, let fileName = customFileName {
                    Text(fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(usingCustomFile ? "Use Sample" : "Choose File...") {
                    if usingCustomFile {
                        previewMarkdown = sampleMarkdown
                        previewHTML = MarkdownDocument.convertToHTML(sampleMarkdown)
                        usingCustomFile = false
                        customFileName = nil
                    } else {
                        choosePreviewFile()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            MarkdownWebView(
                html: previewHTML,
                themeCSS: themeManager.generateCSS(for: currentTheme)
            )
        }
    }

    private func choosePreviewFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose Markdown File for Preview"
        panel.allowedContentTypes = [.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                previewMarkdown = text
                previewHTML = MarkdownDocument.convertToHTML(text)
                usingCustomFile = true
                customFileName = url.lastPathComponent
            }
        }
    }

    private func saveTheme() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            nameErrorMessage = "Theme name is required."
            showNameError = true
            return
        }

        let isRename = trimmedName != editingTheme?.name
        if isRename && themeManager.allThemes.contains(where: { $0.name == trimmedName }) {
            nameErrorMessage = "A theme named \"\(trimmedName)\" already exists."
            showNameError = true
            return
        }
        showNameError = false

        let theme = Theme(
            name: trimmedName,
            colors: colors,
            fonts: fonts,
            sizes: sizes,
            customCSS: customCSS
        )

        do {
            try themeManager.saveUserTheme(theme)
            themeManager.activeThemeName = trimmedName
            ThemeEditorWindowController.shared.close()
        } catch {
            print("Failed to save theme: \(error)")
        }
    }
}

extension Color {
    func toHex() -> String {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
