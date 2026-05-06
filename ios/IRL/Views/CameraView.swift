import Combine
import SwiftUI
import AVFoundation
import CoreLocation
import PhotosUI
import UIKit

// MARK: - CameraMode

enum CameraMode: String, CaseIterable {
    case photo = "Photo"
    case video = "Video"
    case short = "Short"
}

// MARK: - CameraService

@preconcurrency
final class CameraService: NSObject, ObservableObject, @unchecked Sendable {

    @Published var isSessionRunning = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var isRecording = false
    @Published var capturedPhoto: UIImage?
    @Published var recordedVideoURL: URL?
    @Published var recordedDuration: TimeInterval = 0

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var recordingTimer: Timer?
    private var recordingStartDate: Date?

    private let sessionQueue = DispatchQueue(label: "com.irl.camera.session")

    func configure() {
        sessionQueue.async { [self] in
            setupSession()
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        let position = cameraPosition
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()
        session.startRunning()

        DispatchQueue.main.async {
            self.isSessionRunning = true
        }
    }

    func flipCamera() {
        let newPosition: AVCaptureDevice.Position = (cameraPosition == .back) ? .front : .back

        sessionQueue.async { [self] in
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { return }

            session.beginConfiguration()
            if let currentInput {
                session.removeInput(currentInput)
            }
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                self.currentInput = newInput
            }
            session.commitConfiguration()

            DispatchQueue.main.async {
                self.cameraPosition = newPosition
            }
        }
    }

    func toggleFlash() {
        flashMode = (flashMode == .off) ? .on : .off
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if let device = currentInput?.device, device.hasFlash {
            settings.flashMode = flashMode
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func startRecording() {
        guard !isRecording else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        if flashMode == .on, let device = currentInput?.device, device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = .on
            device.unlockForConfiguration()
        }

        movieOutput.startRecording(to: tempURL, recordingDelegate: self)
        isRecording = true
        recordedDuration = 0
        recordingStartDate = Date()
        startRecordingTimer()
    }

    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
        stopRecordingTimer()

        if let device = currentInput?.device, device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        }

        isRecording = false
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartDate else { return }
            DispatchQueue.main.async {
                self.recordedDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    func resetCapture() {
        capturedPhoto = nil
        recordedVideoURL = nil
        recordedDuration = 0
    }

    func stopSession() {
        sessionQueue.async { [self] in
            session.stopRunning()
        }
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async {
            self.capturedPhoto = image
        }
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        DispatchQueue.main.async {
            self.recordedVideoURL = outputFileURL
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

// MARK: - CameraView

struct CameraView: View {

    @EnvironmentObject var postStore: PostStore
    enum PublishMode { case post, story }

    @StateObject private var camera = CameraService()

    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var mode: CameraMode = .photo
    @State private var caption: String = ""
    @State private var publishMode: PublishMode = .post
    @State private var showPosted = false
    @State private var showLocation = true
    @State private var locationName: String = ""
    @State private var galleryItem: PhotosPickerItem?
    @State private var importedTrustLevel: TrustLevel = .verified

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch cameraPermission {
            case .authorized:
                if hasCapture {
                    previewContent
                } else {
                    liveCameraContent
                }
            case .denied, .restricted:
                permissionDeniedView
            default:
                requestingView
            }

            // Posted confirmation
            if showPosted {
                postedOverlay
            }
        }
        // theme controlled globally from IRLApp
        .onAppear {
            checkPermission()
        }
        .onChange(of: galleryItem) { _, newItem in
            Task {
                guard let newItem else { return }
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // Verify EXIF metadata
                    importedTrustLevel = MediaVerifier.verifyImageData(data)
                    camera.capturedPhoto = image
                    resolveLocation()
                }
            }
        }
    }

    // MARK: - Live Camera

    private var liveCameraContent: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Spacer()
                    Button { camera.toggleFlash() } label: {
                        Image(systemName: camera.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(camera.flashMode == .on ? .yellow : .white)
                            .frame(width: 44, height: 44)
                    }
                    Button { camera.flipCamera() } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)

                Spacer()

                if camera.isRecording {
                    recordingBadge
                        .padding(.bottom, 16)
                }

                HStack(alignment: .center) {
                    // Gallery button — camera roll upload
                    PhotosPicker(selection: $galleryItem, matching: .any(of: [.images, .videos])) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()

                    captureButton

                    Spacer()

                    // Flip camera
                    Button { camera.flipCamera() } label: {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)

                modePicker
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Capture Button

    private var captureButton: some View {
        Button {
            handleCapture()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 4)
                    .frame(width: 80, height: 80)

                if mode == .photo {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 66, height: 66)
                } else {
                    if camera.isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 66, height: 66)
                    }
                }
            }
        }
    }

    private var recordingBadge: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.red).frame(width: 8, height: 8)
            Text(formattedDuration(camera.recordedDuration))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }

    private var modePicker: some View {
        HStack(spacing: 24) {
            ForEach(CameraMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { mode = m }
                } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: mode == m ? .bold : .medium, design: .rounded))
                        .foregroundStyle(mode == m ? .white : .white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Preview (after capture)

    private var previewContent: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // Media preview — shrinks when keyboard appears
            GeometryReader { geo in
                if let photo = camera.capturedPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let videoURL = camera.recordedVideoURL,
                          let thumb = generateThumbnail(for: videoURL) {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                }
            }

            // Controls overlay — uses VStack that keyboard can push up
            VStack(spacing: 0) {
                HStack {
                    Button { retake() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Retake")
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    }
                    Spacer()

                    TrustBadgeView(level: importedTrustLevel)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 54) // Clear the status bar

                Spacer()

                VStack(spacing: 10) {
                    // Location tag
                    if showLocation {
                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(IRLColors.earthGreen)

                            if locationName.isEmpty {
                                Text("Adding location...")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            } else {
                                Text(locationName)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            Button {
                                withAnimation { showLocation = false }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(width: 24, height: 24)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        // Tap to re-add location
                        Button {
                            withAnimation { showLocation = true }
                            resolveLocation()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 12))
                                Text("Add location")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }

                    // Publish mode toggle
                    publishModeToggle
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    // Caption + Post
                    HStack(spacing: 10) {
                        TextField("Add a caption...", text: $caption)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(.white)
                            .submitLabel(.done)
                            .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 24))

                        Button {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            postCapture()
                        } label: {
                            Text(publishMode == .post ? "Post" : "Story")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(publishMode == .post ? IRLColors.oceanBlue : IRLColors.earthGreen)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Posted overlay

    private var postedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(IRLColors.earthGreen)
            Text("Posted")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
        .transition(.opacity)
    }

    // MARK: - Permission views

    private var requestingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            Button("Enable Camera") { requestPermission() }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 32).padding(.vertical, 14)
                .background(.white)
                .clipShape(Capsule())
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.3))
            Text("Camera access needed")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 32).padding(.vertical, 14)
            .background(.white)
            .clipShape(Capsule())
        }
    }

    // MARK: - Helpers

    private var hasCapture: Bool {
        camera.capturedPhoto != nil || camera.recordedVideoURL != nil
    }

    private func checkPermission() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraPermission == .authorized {
            camera.configure()
        }
    }

    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermission = granted ? .authorized : .denied
                if granted { camera.configure() }
            }
        }
    }

    private func handleCapture() {
        // Request fresh location for this capture
        LocationService.shared.requestLocation()

        switch mode {
        case .photo:
            camera.capturePhoto()
            resolveLocation()
        case .video, .short:
            if camera.isRecording {
                camera.stopRecording()
                resolveLocation()
            } else {
                camera.startRecording()
            }
        }
    }

    private func retake() {
        caption = ""
        showLocation = true
        locationName = ""
        importedTrustLevel = .verified
        galleryItem = nil
        camera.resetCapture()
    }

    private func resolveLocation() {
        // Request fresh location
        LocationService.shared.requestLocation()

        // Small delay to let GPS update
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let location = LocationService.shared.currentLocation else {
                locationName = ""
                return
            }
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                if let place = placemarks?.first {
                    // Use subLocality (neighborhood) if available, then locality (city)
                    let name = place.subLocality ?? place.locality
                    let parts = [name, place.administrativeArea].compactMap { $0 }
                    locationName = parts.joined(separator: ", ")
                }
            }
        }
    }

    private func postCapture() {
        let cap = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let capValue = cap.isEmpty ? nil : cap

        print("[IRL] postCapture called, mode: \(publishMode), photo: \(camera.capturedPhoto != nil), video: \(camera.recordedVideoURL != nil)")

        if publishMode == .story {
            publishAsStory(captionText: capValue)
        } else {
            if let photo = camera.capturedPhoto {
                postStore.savePhoto(image: photo, caption: capValue, trustLevel: importedTrustLevel)
            } else if let videoURL = camera.recordedVideoURL {
                postStore.saveVideo(sourceURL: videoURL, duration: camera.recordedDuration, caption: capValue)
            }
        }

        // Show confirmation then reset
        withAnimation { showPosted = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showPosted = false }
            self.caption = ""
            self.publishMode = .post
            self.camera.resetCapture()
        }
    }

    /// Encrypt the caption (when present) under a fresh content key sealed for each
    /// audience member, then post the captured photo OR video as base64 alongside.
    private func publishAsStory(captionText: String?) {
        // Capture media bytes + type before going async
        var mediaBase64: String?
        var mediaType: String = "photo"

        if let photo = camera.capturedPhoto {
            mediaBase64 = photo.jpegData(compressionQuality: 0.85)?.base64EncodedString()
            mediaType = "photo"
        } else if let videoURL = camera.recordedVideoURL,
                  let data = try? Data(contentsOf: videoURL) {
            mediaBase64 = data.base64EncodedString()
            mediaType = "video"
        } else {
            // Text-only stories use the StoryComposerSheet path.
            return
        }

        Task {
            do {
                let audience = (try? await APIClient.shared.getStoryAudience()) ?? []
                let recipientsWithKeys = audience.filter { $0.encryptionPublicKey != nil }

                var sealedCaption: String? = nil
                var envelopes: [(recipientId: String, sealedKey: String)] = []

                if let captionText, !recipientsWithKeys.isEmpty {
                    let key = CryptoService.freshContentKey()
                    sealedCaption = try CryptoService.encryptContent(captionText, under: key)
                    for r in recipientsWithKeys {
                        if let pub = r.encryptionPublicKey,
                           let sealed = try? CryptoService.sealContentKey(key, forRecipientPubKeyBase64: pub) {
                            envelopes.append((recipientId: r.id, sealedKey: sealed))
                        }
                    }
                } else {
                    sealedCaption = captionText
                }

                _ = try await APIClient.shared.createStory(
                    encryptedContent: sealedCaption,
                    encryptedMediaUrl: mediaBase64,
                    mediaType: mediaType,
                    trustLevel: importedTrustLevel.rawValue,
                    envelopes: envelopes
                )
                print("[IRL] Story published (\(mediaType))")
            } catch {
                print("[IRL] Story publish failed: \(error.localizedDescription)")
            }
        }
    }

    private var publishModeToggle: some View {
        HStack(spacing: 0) {
            ForEach([PublishMode.post, .story], id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        publishMode = mode
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode == .post ? "square.grid.2x2" : "sparkles")
                            .font(.system(size: 11))
                        Text(mode == .post ? "Post" : "Story · 24h")
                            .font(.system(size: 12, weight: publishMode == mode ? .bold : .medium, design: .rounded))
                    }
                    .foregroundStyle(publishMode == mode ? .white : .white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(publishMode == mode ? Color.white.opacity(0.18) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private func generateThumbnail(for url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 800, height: 800)
        if let cg = try? gen.copyCGImage(at: .zero, actualTime: nil) {
            return UIImage(cgImage: cg)
        }
        return nil
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    CameraView()
        .environmentObject(PostStore())
}
