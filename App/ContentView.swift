//
//  ContentView.swift
//  Widgetnimation
//
//  Created by 길지훈 on 2/24/26.
//

import PhotosUI
import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isGenerating = false
    @State private var resultMessage: String?

    // 디버그용
    @State private var showDebugSection = false
    @State private var debugResult: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                imagePickerSection
                generateButton
                resultSection
                debugSection
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
        }
    }

    // MARK: - 헤더

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "widget.small")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("Widgetnimation")
                .font(.title2.bold())
        }
    }

    // MARK: - 이미지 선택

    private var imagePickerSection: some View {
        VStack(spacing: 12) {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            PhotosPicker(
                selection: $selectedItem,
                matching: .images
            ) {
                Label(
                    selectedImage == nil ? "이미지 선택" : "다른 이미지 선택",
                    systemImage: "photo.on.rectangle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .onChange(of: selectedItem) { _, newItem in
                Task { await loadImage(from: newItem) }
            }
        }
    }

    // MARK: - 위젯 생성 버튼

    private var generateButton: some View {
        Button {
            Task { await generateWidgetFrames() }
        } label: {
            HStack {
                if isGenerating { ProgressView().controlSize(.small) }
                Text(isGenerating ? "생성 중..." : "위젯 이미지 생성")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedImage == nil || isGenerating)
    }

    // MARK: - 결과 표시

    @ViewBuilder
    private var resultSection: some View {
        if let resultMessage {
            Text(resultMessage)
                .font(.callout)
                .foregroundStyle(resultMessage.contains("✓") ? .green : .red)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 디버그 섹션

    private var debugSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation { showDebugSection.toggle() }
            } label: {
                HStack {
                    Text("디버그")
                        .font(.caption)
                    Image(systemName: showDebugSection ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            if showDebugSection {
                VStack(spacing: 8) {
                    Button("App Group 프레임 삭제") {
                        try? FrameStorage.deleteAllFrames()
                        debugResult = "App Group 프레임 삭제됨"
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)

                    if let debugResult {
                        Text(debugResult)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - 이미지 로드

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            selectedImage = nil
            return
        }
        selectedImage = image
        resultMessage = nil
    }

    // MARK: - 위젯 프레임 생성 파이프라인

    private func generateWidgetFrames() async {
        guard let image = selectedImage else { return }
        isGenerating = true
        defer { isGenerating = false }

        // 1. 키링 프레임 + 사용자 이미지 합성 → PNG 30개
        guard let pngFrames = FrameCompositor.generateFrames(from: image) else {
            resultMessage = "✗ 이미지 합성 실패"
            return
        }

        // 2. App Group에 PNG 저장
        do {
            try FrameStorage.saveAllFrames(pngFrames)
        } catch {
            resultMessage = "✗ 저장 실패: \(error.localizedDescription)"
            return
        }

        // 3. Widget 타임라인 리로드
        WidgetCenter.shared.reloadAllTimelines()

        resultMessage = "✓ 위젯 이미지 생성 완료! 위젯을 확인하세요."
    }
}

#Preview {
    ContentView()
}
