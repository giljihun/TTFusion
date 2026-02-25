//
//  ContentView.swift
//  Widgetnimation
//
//  Created by 길지훈 on 2/24/26.
//

import PhotosUI
import SwiftUI
import WidgetKit

/**
 Main screen for compositing a user's photo into keyring widget frames.

 The flow is:
 1) User picks a photo from their library
 2) Tap "Generate" — FrameCompositor composites 30 PNG frames
 3) Frames are saved to App Group, widget timeline is reloaded
 4) The widget immediately picks up the new frames
 */
struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isGenerating = false
    @State private var resultMessage: String?

    @State private var hasFrames = FrameStorage.hasCustomFrames

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            headerSection
            imagePickerSection
            generateButton
            deleteButton
            resultSection

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "widget.small")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Widgetnimation Sample 😆")
                .font(.title3.bold())
        }
    }

    private var imagePickerSection: some View {
        VStack(spacing: 28) {
            Group {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "questionmark.square.dashed")
                        .font(.system(size: 60))
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                Label(
                    selectedImage == nil ? "Select Image" : "Change Image",
                    systemImage: "photo.on.rectangle"
                )
                .frame(width: 160, height: 32)
            }
            .buttonStyle(.bordered)
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadImage(from: newItem) }
            }
        }
    }

    private var generateButton: some View {
        Button {
            Task { await generateWidgetFrames() }
        } label: {
            HStack {
                if isGenerating { ProgressView().controlSize(.small) }
                Text(isGenerating ? "Generating..." : "Generate Widget")
            }
            .frame(width: 160, height: 32)
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedImage == nil || isGenerating)
    }

    private var deleteButton: some View {
        Button {
            try? FrameStorage.deleteAllFrames()
            WidgetCenter.shared.reloadAllTimelines()
            hasFrames = false
            selectedItem = nil
            selectedImage = nil
            resultMessage = nil
        } label: {
            Text("Delete Frames")
                .frame(width: 160, height: 32)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(!hasFrames)
    }

    private var resultSection: some View {
        Text(resultMessage ?? " ")
            .font(.callout)
            .foregroundStyle(resultMessage?.contains("✓") == true ? .green : .red)
            .multilineTextAlignment(.center)
            .opacity(resultMessage == nil ? 0 : 1)
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            selectedImage = nil
            return
        }
        // Normalize EXIF orientation — some photos store pixels
        // in landscape and rely on metadata to rotate for display.
        // Re-drawing into a new context bakes the rotation into
        // the actual pixel data so it always displays upright.
        selectedImage = image.normalizedOrientation()
        resultMessage = nil
    }

    /**
     The generation pipeline runs on a background thread:
     1) FrameCompositor composites user image onto 30 keyring frames
     2) FrameStorage saves the PNGs to the App Group container
     3) WidgetCenter reloads all timelines so the widget picks up new frames
     */
    private func generateWidgetFrames() async {
        guard let image = selectedImage else { return }
        isGenerating = true
        defer { isGenerating = false }

        let pngFrames = await Task.detached {
            FrameCompositor.generateFrames(from: image)
        }.value

        guard let pngFrames else {
            resultMessage = "✗ Compositing failed"
            return
        }

        do {
            try FrameStorage.saveAllFrames(pngFrames)
        } catch {
            resultMessage = "✗ Save failed: \(error.localizedDescription)"
            return
        }

        WidgetCenter.shared.reloadAllTimelines()

        hasFrames = true
        resultMessage = "✓ Done! Check your widget."
    }
}

extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalized ?? self
    }
}
