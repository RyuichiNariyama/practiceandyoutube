//
//  ContentView.swift
//  practiceandyoutube
//
//  Created by 成山 隆一 on 2025/12/02.
//

import SwiftUI
import AVFoundation
import WebKit

struct ContentView: View {
    @State private var practiceMinutes: Double = 1
    @State private var youtubeMinutes: Double = 1
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var elapsedTime: TimeInterval = 0
    @State private var canEndPractice = false
    @State private var showYoutube = false
    @State private var peakHistory: [Float] = Array(repeating: 0, count: 20)
    
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 30) {
            if !isRecording && !showYoutube {
                inputView
            } else if isRecording && !showYoutube {
                recordingView
            } else if showYoutube {
                YoutubeView()
            }
        }
        .padding()
        .onReceive(timer) { _ in
            if isRecording { updateAudioLevel() }
        }
    }
    
    // --- 入力画面 ---
    var inputView: some View {
        VStack {
            HStack {
                TextField("A", value: $practiceMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                Text("分練習したら")
            }
            HStack {
                Text("YouTube ")
                TextField("B", value: $youtubeMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                Text("分")
            }
            Button("スタート") { startRecording() }
                .padding()
        }
    }
    
    func logHeight(level: Float) -> Float {
        // 0～1の正規化値を log風に変換
        return pow(level, 0.5) // sqrtで対数風に
    }
    
    // --- 練習中画面 ---
    var recordingView: some View {
        VStack(spacing: 20) {
            Text("練習中...")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            ProgressView(value: min(elapsedTime / (practiceMinutes*60),1))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .frame(height: 20)
                .padding()
            
            let remaining = max(Int(practiceMinutes*60 - elapsedTime),0)
            Text("残り時間: \(remaining) 秒")
                .font(.headline)
            

            
            // VUメーター風バー
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<peakHistory.count, id: \.self) { i in
                    Rectangle()
                        .fill(barColor(level: peakHistory[i]))
                        .frame(width: 10, height: 10 + CGFloat(logHeight(level: peakHistory[i])) * 40)
                        .cornerRadius(2)
                }
            }
            .frame(height: 50)
            
            Button("練習終了") { stopRecording() }
                .padding()
                .disabled(!canEndPractice)
        }
        .padding()
    }
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [])
            try session.setActive(true)
            
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            elapsedTime = 0
            canEndPractice = false
            peakHistory = Array(repeating: 0, count: 20)
        } catch {
            print("録音エラー:", error)
        }
    }
    
    func updateAudioLevel() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let peak = max(0, min(1, (recorder.peakPower(forChannel: 0)+160)/160))
        
        // -20dB以上で経過時間カウント
        if recorder.peakPower(forChannel: 0) > -20 { elapsedTime += 0.05 }
        if elapsedTime >= practiceMinutes*60 { canEndPractice = true }
        
        // 履歴更新（古いバーは徐々に減衰）
        peakHistory.removeFirst()
        peakHistory.append(peak)
    }
    
    func barColor(level: Float) -> Color {
        switch level {
        case 0..<0.6: return .blue
        case 0.6..<0.8: return .yellow
        default: return .red
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        showYoutube = true
    }
}

struct YoutubeView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let url = URL(string: "https://www.youtube.com/intl/ALL_jp/kids/")!
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
