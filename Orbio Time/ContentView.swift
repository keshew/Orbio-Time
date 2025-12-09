import SwiftUI
import Combine

enum TimerStatus: String, Codable {
    case finished, cancelled, active, paused
}

struct TimerEntry: Identifiable, Codable {
    var id = UUID()
    let duration: TimeInterval
    let date: Date
    var status: TimerStatus
    var label: String
}

final class TimerViewModel: ObservableObject {
    @Published var selectedMinutes: Int = 1
    @Published var selectedSeconds: Int = 5
    @Published var presetSelected: String? = nil
    
    @Published var timerRunning: Bool = false
    @Published var timeLeft: TimeInterval = 0
    
    @Published var history: [TimerEntry] = []
    
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let historyKey = "timerHistory"
    @Published var totalTime: TimeInterval = 0
    
    init() {
        loadHistory()
    }
    
    func startTimer() {
        totalTime = TimeInterval(selectedMinutes * 60 + selectedSeconds)
        timeLeft = totalTime
        timerRunning = true
        
        let newEntry = TimerEntry(duration: totalTime, date: Date(), status: .active, label: timerLabel())
        history.insert(newEntry, at: 0)
        saveHistory()
        setupTimer()
    }
    
    func setupTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func resumeTimer() {
          timerRunning = true
          
          if !history.isEmpty {
              history[0].status = .active
              saveHistory()
          }
          setupTimer()
      }
    
    func tick() {
        guard timeLeft > 0 else {
            timer?.invalidate()
            timerRunning = false
            
            if !history.isEmpty {
                history[0].status = .finished
                saveHistory()
            }
            return
        }
        timeLeft -= 1
    }
    
    func pauseTimer() {
        timer?.invalidate()
        timerRunning = false
        
        if !history.isEmpty {
            history[0].status = .paused
            saveHistory()
        }
    }
    
    func cancelTimer() {
        timer?.invalidate()
        timerRunning = false
        timeLeft = 0
        totalTime = 0
        
        if !history.isEmpty {
            history[0].status = .cancelled
            saveHistory()
        }
    }
       
       func selectedTime() -> TimeInterval {
           totalTime > 0 ? totalTime : TimeInterval(selectedMinutes * 60 + selectedSeconds)
       }
    
    private func updateLatestHistoryEntry(status: TimerStatus) {
        guard !history.isEmpty else { return }
        history[0].status = status
        saveHistory()
    }
    
    func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([TimerEntry].self, from: data) {
            history = saved
        }
    }
    
    func clearHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
    
    private func timerLabel() -> String {
        if let preset = presetSelected {
            return preset
        } else {
            return String(format: "%02d:%02d", selectedMinutes, selectedSeconds)
        }
    }
}

struct Bubble: View {
    let numberText: String
    let color: Color
    let size: CGFloat
    var isSelected: Bool = false
    var onTap: () -> Void
    
    @State private var popped = false
    
    var body: some View {
        ZStack {
            if !popped {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.9), color.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.8), lineWidth: 2)
                            .blur(radius: 2)
                    )
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .blur(radius: 8)
                    )
                    .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
                    .overlay(
                        Text(numberText)
                            .foregroundColor(.white)
                            .font(.system(size: size * 0.35, weight: .bold))
                            .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 0)
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.3)) {
                            popped = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            popped = false
                            onTap()
                        }
                    }
            }
        }
    }
}

struct SetTimerView: View {
    @ObservedObject var vm: TimerViewModel
    @Binding var selectedTab: Int
    
    @State private var showCustomInput = false
    @State private var customMinutes = ""
    @State private var customSeconds = ""
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Bubble Timer")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 8)
                .background(
                    ZStack {
                        Text("Bubble Timer")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.pink)
                            .blur(radius: 8)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.pink.opacity(0.7), lineWidth: 3)
                        .shadow(color: Color.pink.opacity(0.8), radius: 12, x: 0, y: 0)
                        .blur(radius: 10)
                )
                .padding(.top, 30)
            
            Spacer()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(1..<61) { minute in
                        Bubble(
                            numberText: "\(minute)",
                            color: Color(#colorLiteral(red: 1, green: 0.302, blue: 0.824, alpha: 1)),
                            size: 60,
                            isSelected: vm.selectedMinutes == minute && vm.presetSelected == nil
                        ) {
                            vm.selectedMinutes = minute
                            vm.presetSelected = nil
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 28)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { second in
                        Bubble(
                            numberText: "\(second)",
                            color: Color(#colorLiteral(red: 0, green: 0.898, blue: 1, alpha: 1)),
                            size: 50,
                            isSelected: vm.selectedSeconds == second && vm.presetSelected == nil
                        ) {
                            vm.selectedSeconds = second
                            vm.presetSelected = nil
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 28)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    let presets = ["1m", "5m", "10m", "+"]
                    ForEach(presets, id: \.self) { preset in
                        Bubble(
                            numberText: preset,
                            color: Color(#colorLiteral(red: 0.659, green: 1, blue: 0, alpha: 1)),
                            size: 50,
                            isSelected: vm.presetSelected == preset
                        ) {
                            vm.presetSelected = preset
                            switch preset {
                            case "1m":
                                vm.selectedMinutes = 1
                                vm.selectedSeconds = 0
                            case "5m":
                                vm.selectedMinutes = 5
                                vm.selectedSeconds = 0
                            case "10m":
                                vm.selectedMinutes = 10
                                vm.selectedSeconds = 0
                            case "Custom":
                                showCustomInput = true
                            default:
                                break
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 28)
            }
            
            Button(action: {
                vm.startTimer()
                selectedTab = 1
            }) {
                Circle()
                    .fill(
                        RadialGradient(gradient: Gradient(colors: [Color(#colorLiteral(red: 1, green: 0.698, blue: 0, alpha: 1)), Color(#colorLiteral(red: 1, green: 0.447, blue: 0, alpha: 1))]), center: .center, startRadius: 10, endRadius: 40)
                    )
                    .frame(width: 120, height: 120)
                    .overlay(Text("Start")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .shadow(radius: 5))
                    .shadow(color: Color.orange.opacity(0.6), radius: 10, x: 0, y: 5)
                    .scaleEffect(vm.timerRunning ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: vm.timerRunning)
            }
            .padding(.top, 30)
            
            Spacer()
            
            Button(action: {
                selectedTab = 2
            }) {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(Color.white.opacity(0.9))
                                .font(.system(size: 20)))
            }
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(#colorLiteral(red: 0.1686, green: 0, blue: 0.4, alpha: 1)), Color(#colorLiteral(red: 0, green: 0.2, blue: 0.4, alpha: 1))]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
        )
        .sheet(isPresented: $showCustomInput) {
            CustomTimeInputView(vm: vm, isPresented: $showCustomInput)
        }
    }
}

struct CustomTimeInputView: View {
    @ObservedObject var vm: TimerViewModel
    @Binding var isPresented: Bool
    
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter custom time").font(.headline)) {
                    TextField("Minutes", text: $minutes)
                        .keyboardType(.numberPad)
                    TextField("Seconds", text: $seconds)
                        .keyboardType(.numberPad)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
                
                Button("Set Timer") {
                    let minVal = Int(minutes) ?? 0
                    let secVal = Int(seconds) ?? 0
                    
                    if minVal < 0 || secVal < 0 || secVal >= 60 {
                        errorMessage = "Please enter valid time (0–59 seconds)"
                    } else if minVal == 0 && secVal == 0 {
                        errorMessage = "Time cannot be zero"
                    } else {
                        vm.selectedMinutes = minVal
                        vm.selectedSeconds = secVal
                        vm.presetSelected = "Custom"
                        errorMessage = nil
                        isPresented = false
                    }
                }
                .disabled(minutes.isEmpty && seconds.isEmpty)
            }
            .navigationTitle("Custom Timer")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}


extension View {
    func neonBorder(color: Color, lineWidth: CGFloat = 3, cornerRadius: CGFloat = 10) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color.opacity(0.8), lineWidth: lineWidth)
                .shadow(color: color, radius: 10)
        )
    }
}

struct TabBarView: View {
    @StateObject var vm = TimerViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SetTimerView(vm: vm, selectedTab: $selectedTab)
                .tabItem {
                    BubbleTabIcon(color: Color(#colorLiteral(red: 1, green: 0.302, blue: 0.824, alpha: 1)), systemName: "clock.fill")
                    Text("Set Timer")
                }
                .tag(0)
            
            CountdownView(vm: vm)
                .tabItem {
                    BubbleTabIcon(color: Color(#colorLiteral(red: 0, green: 0.898, blue: 1, alpha: 1)), systemName: "timer")
                    Text("Countdown")
                }
                .tag(1)
            
            HistoryView(vm: vm)
                .tabItem {
                    BubbleTabIcon(color: Color(.gray), systemName: "clock.arrow.circlepath")
                    Text("History")
                }
                .tag(2)
            
            SettingsView(vm: vm)
                .tabItem {
                    BubbleTabIcon(color: Color(#colorLiteral(red: 0.659, green: 1, blue: 0, alpha: 1)), systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(3)
        }
        .accentColor(.white)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(#colorLiteral(red: 0.1686, green: 0, blue: 0.4, alpha: 1)), Color(#colorLiteral(red: 0, green: 0.2, blue: 0.4, alpha: 1))]),
                startPoint: .top,
                endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
        )
    }
}

import SwiftUI

struct HistoryView: View {
    @ObservedObject var vm: TimerViewModel
    
    var body: some View {
        VStack {
            HStack {
                Text("History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    vm.clearHistory()
                }) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 100, height: 36)
                        .overlay(
                            Text("Clear history")
                                .foregroundColor(.white)
                                .font(.callout)
                        )
                        .shadow(color: Color.white.opacity(0.5), radius: 2, x: 0, y: 2)
                }
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(vm.history.prefix(10)) { entry in
                        HistoryBubbleView(entry: entry)
                            .padding(.horizontal)
                    }
                }
            }
            
            Spacer(minLength: 20)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(#colorLiteral(red: 0.1686, green: 0, blue: 0.4, alpha: 1)), Color(#colorLiteral(red: 0, green: 0.2, blue: 0.4, alpha: 1))]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
        )
    }
}

import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: TimerViewModel
    
    @State private var soundOn: Bool = true
    @State private var vibrationOn: Bool = true
    @State private var showWave = false
    @State private var selectedTheme = 0
    
    let themeOptions = ["Purple Blue", "Pink Blue", "Green Lime"]
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 40)
            
            HStack {
                Text("Sound")
                    .foregroundColor(.white)
                    .font(.title2)
                Spacer()
                GlowToggle(isOn: $soundOn, color: .yellow) {
                    withAnimation(.easeOut(duration: 0.6)) {
                        showWave = soundOn
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showWave = false
                    }
                }
            }
            .padding(.horizontal, 30)
            
            if showWave {
                WaveBubble()
                    .frame(width: 60, height: 60)
            }
            
            HStack {
                Text("Vibration")
                    .foregroundColor(.white)
                    .font(.title2)
                Spacer()
                GlowToggle(isOn: $vibrationOn, color: .cyan)
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(#colorLiteral(red: 0.1686, green: 0, blue: 0.4, alpha: 1)), Color(#colorLiteral(red: 0, green: 0.2, blue: 0.4, alpha: 1))]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
        )
    }
}

struct GlowToggle: View {
    @Binding var isOn: Bool
    var color: Color
    var onToggle: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            isOn.toggle()
            onToggle?()
        }) {
            Circle()
                .fill(isOn ? color : color.opacity(0.3))
                .frame(width: 50, height: 50)
                .shadow(color: isOn ? color.opacity(0.8) : .clear, radius: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isOn ? 0.6 : 0), lineWidth: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.3), value: isOn)
    }
}

struct WaveBubble: View {
    @State private var animate = false
    
    var body: some View {
        Circle()
            .stroke(Color.yellow.opacity(0.6), lineWidth: 4)
            .frame(width: 60, height: 60)
            .scaleEffect(animate ? 1.3 : 0.8)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(Animation.easeOut(duration: 0.6).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}


struct HistoryBubbleView: View {
    let entry: TimerEntry
    
    var bubbleColor: Color {
        switch entry.status {
        case .finished:
            return Color(#colorLiteral(red: 1, green: 0.302, blue: 0.824, alpha: 1))
        case .cancelled:
            return Color.gray
        case .active:
            return Color(#colorLiteral(red: 0, green: 0.898, blue: 1, alpha: 1))
        case .paused:
            return Color(#colorLiteral(red: 0, green: 0.898, blue: 1, alpha: 1))
        }
    }
    
    var statusText: String {
        switch entry.status {
        case .finished: return "Finished ✅"
        case .cancelled: return "Cancelled ❌"
        case .active: return "Active ⏳"
        case .paused: return "Paused ⏸"
        }
    }
    
    var body: some View {
        HStack {
            Capsule()
                .fill(bubbleColor.opacity(0.85))
                .frame(height: 50)
                .overlay(
                    HStack {
                        Text("\(formattedDuration()) – \(statusText)")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.horizontal)
                        Spacer()
                    }
                )
                .shadow(color: bubbleColor.opacity(0.5), radius: 6, x: 0, y: 4)
        }
    }
    
    func formattedDuration() -> String {
        let minutes = Int(entry.duration) / 60
        let seconds = Int(entry.duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}


import SwiftUI

struct CountdownView: View {
    @ObservedObject var vm: TimerViewModel
    
    private func bubbleColor(for timeLeft: TimeInterval, total: TimeInterval) -> Color {
        let progress = timeLeft / total
        if progress > 0.5 {
            return Color(#colorLiteral(red: 1, green: 0.302, blue: 0.824, alpha: 1))
        } else if progress > 0.2 {
            return Color(#colorLiteral(red: 1, green: 0.7, blue: 0, alpha: 1))
        } else {
            return Color.red
        }
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let min = Int(interval) / 60
        let sec = Int(interval) % 60
        return String(format: "%02d:%02d", min, sec)
    }
    
    @State private var bubblePulsate = false
    
    var body: some View {
        ZStack {
              BubbleBackgroundView(paused: !vm.timerRunning)
              
              VStack(spacing: 40) {
                  Spacer()
                  
                  Circle()
                      .fill(
                          RadialGradient(
                              gradient: Gradient(colors: [
                                  bubbleColor(for: vm.timeLeft, total: vm.totalTime),
                                  bubbleColor(for: vm.timeLeft, total: vm.totalTime).opacity(0.7)
                              ]),
                              center: .center,
                              startRadius: 20,
                              endRadius: 100)
                      )
                      .frame(width: 220, height: 220)
                      .overlay(
                          Text(timeString(from: vm.timeLeft))
                              .font(.system(size: 50, weight: .bold, design: .rounded))
                              .foregroundColor(.white)
                              .shadow(radius: 6)
                      )
                      .scaleEffect(bubblePulsate ? 1.05 : 1.0)
                      .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: bubblePulsate)
                      .onAppear {
                          bubblePulsate = true
                      }
                  
                  HStack(spacing: 40) {
                      Button(action: {
                          if vm.timerRunning {
                              vm.pauseTimer()
                          } else {
                              if vm.timeLeft > 0 {
                                  vm.resumeTimer()
                              } else {
                                  vm.startTimer()
                              }
                          }
                      }) {
                          Circle()
                              .fill(Color(#colorLiteral(red: 1, green: 0.698, blue: 0, alpha: 1)))
                              .frame(width: 70, height: 70)
                              .overlay(
                                  Image(systemName: vm.timerRunning ? "pause.fill" : "play.fill")
                                      .font(.system(size: 30))
                                      .foregroundColor(.white)
                                      .shadow(radius: 3)
                              )
                              .shadow(color: Color.orange.opacity(0.8), radius: 6, x: 0, y: 4)
                      }
                      
                      Button(action: {
                          vm.cancelTimer()
                      }) {
                          Circle()
                              .fill(Color.red.opacity(0.7))
                              .frame(width: 70, height: 70)
                              .overlay(
                                  Image(systemName: "xmark")
                                      .font(.system(size: 30, weight: .bold))
                                      .foregroundColor(.white)
                                      .shadow(radius: 3)
                              )
                      }
                  }
                  
                  Text("Estimated finish: \(vm.estimatedFinishTime())")
                      .foregroundColor(Color(#colorLiteral(red: 0.733, green: 0.667, blue: 1, alpha: 1)))
                      .font(.callout)
                      .padding(.top, 30)
                  
                  Spacer()
              }
              .padding()
          }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(#colorLiteral(red: 0.1686, green: 0, blue: 0.4, alpha: 1)), Color(#colorLiteral(red: 0, green: 0.2, blue: 0.4, alpha: 1))]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
        )
    }
}

struct BubbleBackgroundView: View {
    let paused: Bool
    @State private var bubbles = [BubbleModel]()
    let maxBubbles = 20
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bubbles) { bubble in
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: bubble.size, height: bubble.size)
                        .position(x: bubble.x, y: bubble.y)
                        .blur(radius: 3)
                        .opacity(bubble.opacity)
                        .animation(paused ? .none : Animation.linear(duration: bubble.duration).repeatForever(autoreverses: false), value: bubble.y)
                        .onAppear {
                            if !paused {
                                withAnimation {
                                    bubble.y = -bubble.size
                                }
                            }
                        }
                }
            }
            .onAppear {
                if bubbles.isEmpty {
                    for _ in 0..<maxBubbles {
                        let size = CGFloat.random(in: 8...20)
                        let x = CGFloat.random(in: 0...geo.size.width)
                        let y = CGFloat.random(in: geo.size.height...(geo.size.height + 100))
                        let duration = Double.random(in: 8...20)
                        bubbles.append(BubbleModel(id: UUID(), x: x, y: y, size: size, duration: duration, opacity: Double.random(in: 0.05...0.25)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

class BubbleModel: Identifiable, ObservableObject {
    let id: UUID
    @Published var x: CGFloat
    @Published var y: CGFloat
    let size: CGFloat
    let duration: Double
    let opacity: Double
    
    init(id: UUID, x: CGFloat, y: CGFloat, size: CGFloat, duration: Double, opacity: Double) {
        self.id = id
        self.x = x
        self.y = y
        self.size = size
        self.duration = duration
        self.opacity = opacity
    }
}

extension TimerViewModel {
    
    func estimatedFinishTime() -> String {
        let finishDate = Date().addingTimeInterval(timeLeft)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: finishDate)
    }
}


struct BubbleTabIcon: View {
    let color: Color
    let systemName: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [color.opacity(0.9), color.opacity(0.6)]),
                        center: .center,
                        startRadius: 5,
                        endRadius: 20))
                .frame(width: 30, height: 30)
                .shadow(color: color.opacity(0.6), radius: 5, x: 0, y: 3)
            
            Image(systemName: systemName)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .bold))
        }
    }
}
#Preview {
    TabBarView()
}
