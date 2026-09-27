//
//  ProcessInspectorView.swift
//  StikDebug
//
//  Created by Stephen on 11/3/25.
//

import SwiftUI

struct ProcessInspectorView: View {
    @StateObject private var viewModel = ProcessInspectorViewModel()
    @State private var killCandidate: ProcessInfoEntry?
    @State private var killConfirmTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Process Inspector")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: viewModel.refresh) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isRefreshing)
                    }
                }
                .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
        }
        .task {
            await viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .alert(viewModel.actionAlertTitle, isPresented: $viewModel.showActionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.actionAlertMessage)
        }
        .alert(viewModel.errorAlertTitle, isPresented: $viewModel.showErrorAlert) {
            Button("Try Again") { viewModel.refresh() }
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorAlertMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            Section("Overview") {
                LabeledContent("Total Processes") {
                    Text("\(viewModel.processes.count)")
                        .font(.title2.bold())
                }
            }
            Section("Processes") {
                if viewModel.filteredProcesses.isEmpty {
                    Text("No matching processes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.filteredProcesses) { process in
                        ProcessRow(
                            process: process,
                            activeControl: viewModel.activeControl(for: process),
                            isBusy: viewModel.isRunningControlAction,
                            isConfirming: killCandidate?.pid == process.pid,
                            onResumeTap: { viewModel.control(.resume, process: $0) },
                            onPauseTap: { viewModel.control(.pause, process: $0) },
                            onKillTap: { handleKillTap(for: $0) },
                            onDisableMemoryLimitTap: { process in
                                viewModel.control(.disableMemoryLimit, process: process)
        },
        )
        }
        }
        }
        }
        .listStyle(.insetGrouped)
        .refreshable { viewModel.refresh() }
        }
        }
        private extension ProcessInspectorView {
        func handleKillTap(for process: ProcessInfoEntry) {
        if killCandidate?.pid == process.pid {
            killConfirmTask?.cancel()
            killConfirmTask = nil
            killCandidate = nil
            viewModel.control(.kill, process: process)
        } else {
            killCandidate = process
            killConfirmTask?.cancel()
            killConfirmTask = Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run {
                    if killCandidate?.pid == process.pid {
                        killCandidate = nil
                    }
                }
            }
        }
    }
}

// MARK: - Row

enum ProcessControlAction: String {
    case resume
    case pause
    case kill

    var signal: Int32 {
        switch self {
        case .resume:
            return Int32(SIGCONT)
        case .pause:
            return Int32(SIGSTOP)
        case .kill:
            return Int32(SIGKILL)
        }
    }

    var buttonLabel: String {
        switch self {
        case .resume:
            return "Resume"
        case .pause:
            return "Pause"
        case .kill:
            return "Kill"
        }
    }

    var systemImage: String {
        switch self {
        case .resume:
            return "play.circle"
        case .pause:
            return "pause.circle"
        case .kill:
            return "xmark.circle"
        case .disableMemoryLimit:
            return "infinity.circle"    
        } 
     
    }

    var tint: Color {
        switch self {
        case .resume:
            return .green
        case .pause:
            return .orange
        case .kill:
            return .red
        case .disableMemorylimit:
            return .blue    
        }
        }
    var progressTitle: String {
        switch self {
        case .resume:
            return "Resuming Process"
        case .pause:
            return "Pausing Process"
        case .kill:
            return "Terminating Process"
        case .disableMemorylimit:
            return "Disabling Memory Limit"
        }
        }
    
        var timeoutTitle: String {
        switch self {
        case .resume:
            return "Resume Timed Out"
        case .pause:
            return "Pause Timed Out"
        case .kill:
            return "Kill Timed Out"
        case .disableMemoryLimit:
            return "Memory Limit Timed Out"
        }
        }
    
    var failureTitle: String {
        switch self {
        case .resume:
            return "Resume Failed"
        case .pause:
            return "Pause Failed"
        case .kill:
            return "Kill Failed"
        case .disableMemoryLimit:
            return "Memory Limit Failed"
        }
        }
    
    var successTitle: String {
        switch self {
        case .resume:
            return "Process Resumed"
        case .pause:
            return "Process Paused"
        case .kill:
            return "Process Terminated"
        case .disableMemoryLimit:
            return "Memory Limit Disabled"
        }
        }
    func successMessage(for pid: Int) -> String {
        switch self {
        case .resume:
            return "Sent SIGCONT (19) to PID \(pid)."
        case .pause:
            return "Sent SIGSTOP (17) to PID \(pid)."
        case .kill:
            return "PID \(pid) was terminated."
        case .disableMemoryLimit:
            return "Memory Limit Disabled"
        }
        }
    
    func timeoutMessage(for pid: Int) -> String {
        switch self {
        case .resume:
            return "Could not confirm resume for PID \(pid). Try again."
        case .pause:
            return "Could not confirm pause for PID \(pid). Try again."
        case .kill:
            return "Could not confirm termination for PID \(pid). Try again."
        case .disableMemoryLimit:
            return "Could not confirm memory limit change for PID \(pid)."
    }
    }
    private struct ProcessRow: View {
    let process: ProcessInfoEntry
    let activeControl: ProcessControlAction?
    let isBusy: Bool
    let isConfirming: Bool
    let onResumeTap: (ProcessInfoEntry) -> Void
    let onPauseTap: (ProcessInfoEntry) -> Void
    let onKillTap: (ProcessInfoEntry) -> Void
    let onDisableMemoryLimitTap: (ProcessInfoEntry) -> Void 
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(process.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("PID \(process.pid)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let bundle = process.bundleID, !bundle.isEmpty {
                Text(bundle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text(process.executablePath)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack {
                Spacer()
                if activeControl != nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                } else {
                    HStack(spacing: 8) {
                        Button {
                            onResumeTap(process)
                        } label: {
                            Image(systemName: ProcessControlAction.resume.systemImage)
                                .font(.title3)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(ProcessControlAction.resume.tint)
                        .labelStyle(.iconOnly)
                        .disabled(isBusy)

                        Button {
                            onPauseTap(process)
                        } label: {
                            Image(systemName: ProcessControlAction.pause.systemImage)
                                .font(.title3)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(ProcessControlAction.pause.tint)
                        .labelStyle(.iconOnly)
                        .disabled(isBusy)

                        Button {
                            onKillTap(process)
                        } label: {
                            if isConfirming {
                                Label("Confirm", systemImage: "checkmark.circle.fill")
                                    .labelStyle(.iconOnly)
                                    .font(.title3)
                            } else {
                                Image(systemName: ProcessControlAction.kill.systemImage)
                                    .font(.title3)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(isConfirming ? .green : ProcessControlAction.kill.tint)
                        .labelStyle(.iconOnly)
                        .disabled(isBusy)
                    }
                 Button  {
                     onDisableMemoryLimitTap(process)
                 } label: {
                     Image(systemName: ProcessControlAction.disableMemoryLimit.systemImage)
                         .font(.title3)
                 }
                 .buttonStyle(.bordered)
                 .controlSize(.small)
                 .tint(ProcessControlAction.disableMemoryLimit.tint)
                 .labelStyle(.iconOnly)
                 .disabled(isBusy)
            } 
        }
    
    }
     .padding(.vertical, 4)
  }
}
    
// MARK: - View Model
@MainActor
final class ProcessInspectorViewModel: ObservableObject {
    @Published var actionAlertMessage = ""
    
    private var refreshTask: Task<Void, Never>?
    private var controlTimeoutTask: Task<Void, Never>?
    @Published private(set) var lastUpdated: Date?

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var filteredProcesses: [ProcessInfoEntry] {
        guard !searchText.isEmpty else { return processes }
        return processes.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            ($0.bundleID?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            $0.executablePath.localizedCaseInsensitiveContains(searchText) ||
            "\($0.pid)".contains(searchText)
        }
    }
    
    var lastUpdatedText: String {
        guard let date = lastUpdated else { return "—" }
        return Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    func startAutoRefresh() async {
        refresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self else { break }
                await MainActor.run {
                    self.refresh()
                }
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        controlTimeoutTask?.cancel()
        controlTimeoutTask = nil
    }
    
    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            var err: NSError?
            let parsedEntries = ProcessInfoEntry.currentEntries(&err)
            let errorMessage = err?.localizedDescription
            await MainActor.run {
                if let errorMessage {
                    self.errorAlertTitle = "Failed to Load Processes"
                    self.errorAlertMessage = errorMessage
                    self.showErrorAlert = true
                } else {
                    self.processes = parsedEntries
                    self.lastUpdated = Date()
                }
                self.isRefreshing = false
            }
        }
    }
    
    var isRunningControlAction: Bool {
        activeControlState != nil
    }

    func activeControl(for process: ProcessInfoEntry) -> ProcessControlAction? {
        guard activeControlState?.pid == process.pid else { return nil }
        return activeControlState?.action
    }

    func control(_ action: ProcessControlAction, process: ProcessInfoEntry) {
        guard activeControlState == nil else {
            actionAlertTitle = "Busy"
            if let activeControlState {
                actionAlertMessage = "\(activeControlState.action.progressTitle) for PID \(activeControlState.pid)."
            } else {
                actionAlertMessage = "Another process action is already running."
            }
            showActionAlert = true
            return
        }
        let targetPID = process.pid
        activeControlState = (targetPID, action)
        controlTimeoutTask?.cancel()
        controlTimeoutTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(8))
            if self.activeControlState?.pid == targetPID && self.activeControlState?.action == action {
                self.activeControlState = nil
                self.actionAlertTitle = action.timeoutTitle
                self.actionAlertMessage = action.timeoutMessage(for: targetPID)
                self.showActionAlert = true
            }
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var err: NSError?
            let success: Bool
            do {
                if action == .disableMemoryLimit {
                    try JITEnableContext.shared.disableMemoryLimit(forPID: In32(targetPID))
                } else {
                    try JITEnableContext.shared.senSignal(
                        action.signal,
                        toProcessWithPID: Int32(targetPID)
                    )
                }
                success = true
            } catch let nsError as NSError {
                err = nsError
                success = false
            }
            if sucess {
                self.actionAlertTitle = action.successTitle
                self.actionAlertMessage = action.successMessage(for: targetPID)
                self.showActionAlert = true
                self.refresh()
            } else {
                    self.actionAlertMessage = errorMessage
                    self.showActionAlert = true
            }
            }
            }
            }
