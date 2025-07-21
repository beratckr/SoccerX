import SwiftUI
import Combine

struct JoinGroupView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = JoinGroupViewModel()
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Join a Group")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Enter the invite code shared by the group creator")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Invite Code Input
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Invite Code", systemImage: "link")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                ForEach(0..<6, id: \.self) { index in
                                    CodeDigitView(
                                        digit: viewModel.getDigit(at: index),
                                        isActive: index == viewModel.inviteCode.count
                                    )
                                }
                            }
                            .onTapGesture {
                                isCodeFieldFocused = true
                            }
                            
                            // Hidden TextField for input
                            TextField("", text: $viewModel.inviteCode)
                                .keyboardType(.asciiCapable)
                                .textCase(.uppercase)
                                .focused($isCodeFieldFocused)
                                .opacity(0)
                                .frame(height: 0)
                            
                            if let error = viewModel.codeError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // OR Divider
                        HStack {
                            Rectangle()
                                .fill(Color(.systemGray5).opacity(0.3))
                                .frame(height: 1)
                            
                            Text("OR")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .fill(Color(.systemGray5).opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 8)
                        
                        // Browse Public Groups
                        Button(action: {
                            viewModel.showPublicGroups = true
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 18))
                                
                                Text("Browse Public Groups")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.green)
                            .padding(16)
                            .background(Color(.systemGray6).opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Join Button
                    Button(action: {
                        Task {
                            await viewModel.joinGroup()
                        }
                    }) {
                        if viewModel.isJoining {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.green)
                                .cornerRadius(16)
                        } else {
                            Text("Join Group")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.green)
                                .cornerRadius(16)
                        }
                    }
                    .disabled(!viewModel.isCodeValid || viewModel.isJoining)
                    .opacity(viewModel.isCodeValid && !viewModel.isJoining ? 1 : 0.6)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
            .onAppear {
                isCodeFieldFocused = true
            }
            .onReceive(viewModel.$groupJoined) { success in
                if success {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $viewModel.showPublicGroups) {
                PublicGroupsView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct CodeDigitView: View {
    let digit: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.green : Color(.systemGray5).opacity(0.2), lineWidth: 2)
                )
            
            Text(digit)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 60)
        .animation(.easeInOut(duration: 0.1), value: isActive)
    }
}

// MARK: - View Model

class JoinGroupViewModel: ObservableObject {
    @Published var inviteCode = ""
    @Published var isJoining = false
    @Published var groupJoined = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var codeError: String?
    @Published var showPublicGroups = false
    
    private let groupManager = GroupManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    var isCodeValid: Bool {
        inviteCode.count == 6
    }
    
    init() {
        // Format and validate invite code
        $inviteCode
            .sink { [weak self] code in
                self?.formatInviteCode(code)
            }
            .store(in: &cancellables)
    }
    
    func getDigit(at index: Int) -> String {
        guard index < inviteCode.count else { return "" }
        let stringIndex = inviteCode.index(inviteCode.startIndex, offsetBy: index)
        return String(inviteCode[stringIndex])
    }
    
    private func formatInviteCode(_ code: String) {
        // Remove non-alphanumeric characters and convert to uppercase
        let filtered = code.uppercased().filter { $0.isLetter || $0.isNumber }
        
        // Limit to 6 characters
        if filtered.count > 6 {
            inviteCode = String(filtered.prefix(6))
        } else if filtered != code {
            inviteCode = filtered
        }
        
        // Validate
        if !filtered.isEmpty && filtered.count < 6 {
            codeError = "Invite code must be 6 characters"
        } else {
            codeError = nil
        }
    }
    
    @MainActor
    func joinGroup() async {
        guard isCodeValid else { return }
        
        isJoining = true
        errorMessage = ""
        
        do {
            _ = try await groupManager.joinGroup(by: inviteCode).async()
            groupJoined = true
        } catch {
            if let groupError = error as? GroupError {
                switch groupError {
                case .invalidInviteCode:
                    errorMessage = "Invalid invite code. Please check and try again."
                case .groupFull:
                    errorMessage = "This group is full and cannot accept new members."
                case .alreadyMember:
                    errorMessage = "You are already a member of this group."
                default:
                    errorMessage = groupError.localizedDescription
                }
            } else {
                errorMessage = error.localizedDescription
            }
            showError = true
        }
        
        isJoining = false
    }
}

// MARK: - Public Groups View

struct PublicGroupsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = PublicGroupsViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.groups.isEmpty {
                    LoadingView(message: "Loading groups...", style: .soccer)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.filteredGroups) { group in
                                PublicGroupCard(group: group) {
                                    Task {
                                        await viewModel.joinGroup(group)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .searchable(text: $searchText, prompt: "Search groups")
                }
            }
            .navigationTitle("Public Groups")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadPublicGroups()
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                viewModel.filterGroups(newValue)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct PublicGroupCard: View {
    let group: Group
    let onJoin: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("\(group.memberIds.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Join") {
                    onJoin()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green)
                .cornerRadius(8)
            }
            
            if let description = group.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
        )
    }
}

class PublicGroupsViewModel: ObservableObject {
    @Published var groups: [Group] = []
    @Published var filteredGroups: [Group] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    private let groupManager = GroupManager.shared
    
    @MainActor
    func loadPublicGroups() async {
        isLoading = true
        
        do {
            groups = try await groupManager.searchPublicGroups(query: "").async()
            filteredGroups = groups
        } catch {
            errorMessage = "Failed to load public groups"
            showError = true
        }
        
        isLoading = false
    }
    
    func filterGroups(_ searchText: String) {
        if searchText.isEmpty {
            filteredGroups = groups
        } else {
            filteredGroups = groups.filter { group in
                group.name.localizedCaseInsensitiveContains(searchText) ||
                (group.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    @MainActor
    func joinGroup(_ group: Group) async {
        do {
            _ = try await groupManager.joinGroup(by: group.inviteCode).async()
            // Dismiss the sheet after successful join
            NotificationCenter.default.post(name: .groupJoined, object: nil)
        } catch {
            if let groupError = error as? GroupError {
                errorMessage = groupError.localizedDescription
            } else {
                errorMessage = "Failed to join group"
            }
            showError = true
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let groupJoined = Notification.Name("groupJoined")
}

// MARK: - Combine Helpers

extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                    }
                )
        }
    }
}

// MARK: - Preview

#Preview {
    JoinGroupView()
        .preferredColorScheme(.dark)
}