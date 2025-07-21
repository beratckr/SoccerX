import SwiftUI
import Combine

struct CreateGroupView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = CreateGroupViewModel()
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, description
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Create a New Group")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Compete with friends and track your progress together")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            // Group Name
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Group Name", systemImage: "person.3.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                TextField("Enter group name", text: $viewModel.groupName)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .focused($focusedField, equals: .name)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .description
                                    }
                                
                                if let error = viewModel.nameError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // Description
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Description", systemImage: "text.alignleft")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                TextEditor(text: $viewModel.description)
                                    .frame(height: 100)
                                    .padding(12)
                                    .background(Color(.systemGray6).opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
                                    )
                                    .focused($focusedField, equals: .description)
                                    .foregroundColor(.white)
                                
                                Text("\(viewModel.description.count)/200")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            
                            // Privacy Toggle
                            VStack(alignment: .leading, spacing: 16) {
                                Toggle(isOn: $viewModel.isPublic) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Public Group")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                        
                                        Text(viewModel.isPublic ? "Anyone can find and join this group" : "Only people with invite code can join")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tint(.green)
                            }
                            .padding(16)
                            .background(Color(.systemGray6).opacity(0.1))
                            .cornerRadius(12)
                            
                            // Group Features
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Included Features", systemImage: "sparkles")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 8) {
                                    FeatureRow(icon: "trophy", text: "Weekly leaderboards", isIncluded: true)
                                    FeatureRow(icon: "bell", text: "Activity notifications", isIncluded: true)
                                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Group statistics", isIncluded: true)
                                    FeatureRow(icon: "person.badge.plus", text: "Invite up to \(viewModel.maxMembers) members", isIncluded: !viewModel.isPremium)
                                    
                                    if !viewModel.isPremium {
                                        FeatureRow(icon: "crown", text: "Unlimited members with Premium", isIncluded: false, isPremium: true)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom Button
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color(.systemGray5).opacity(0.3))
                        
                        Button(action: {
                            Task {
                                await viewModel.createGroup()
                            }
                        }) {
                            if viewModel.isCreating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.green)
                                    .cornerRadius(16)
                            } else {
                                Text("Create Group")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.green)
                                    .cornerRadius(16)
                            }
                        }
                        .disabled(!viewModel.isFormValid || viewModel.isCreating)
                        .opacity(viewModel.isFormValid && !viewModel.isCreating ? 1 : 0.6)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color.black)
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
            .onReceive(viewModel.$groupCreated) { success in
                if success {
                    presentationMode.wrappedValue.dismiss()
                }
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

struct FeatureRow: View {
    let icon: String
    let text: String
    let isIncluded: Bool
    var isPremium: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isIncluded ? .green : .secondary)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(isIncluded ? .white : .secondary)
            
            Spacer()
            
            if isPremium {
                Text("PRO")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.yellow, Color.orange]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(4)
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5).opacity(0.2), lineWidth: 1)
            )
            .foregroundColor(.white)
    }
}

// MARK: - View Model

class CreateGroupViewModel: ObservableObject {
    @Published var groupName = ""
    @Published var description = ""
    @Published var isPublic = true
    @Published var isCreating = false
    @Published var groupCreated = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var nameError: String?
    
    private let groupManager = GroupManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    var isPremium: Bool {
        // TODO: Check actual subscription status
        return false
    }
    
    var maxMembers: Int {
        return isPremium ? 100 : 10
    }
    
    var isFormValid: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        groupName.count >= 3 &&
        groupName.count <= 50 &&
        description.count <= 200
    }
    
    init() {
        // Validate group name
        $groupName
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] name in
                self?.validateGroupName(name)
            }
            .store(in: &cancellables)
        
        // Limit description length
        $description
            .sink { [weak self] desc in
                if desc.count > 200 {
                    self?.description = String(desc.prefix(200))
                }
            }
            .store(in: &cancellables)
    }
    
    private func validateGroupName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            nameError = nil
        } else if trimmed.count < 3 {
            nameError = "Group name must be at least 3 characters"
        } else if trimmed.count > 50 {
            nameError = "Group name must be less than 50 characters"
        } else {
            nameError = nil
        }
    }
    
    @MainActor
    func createGroup() async {
        guard isFormValid else { return }
        
        isCreating = true
        errorMessage = ""
        
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            _ = try await groupManager.createGroup(
                name: trimmedName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                isPublic: isPublic
            ).async()
            
            groupCreated = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isCreating = false
    }
}

// MARK: - Preview

#Preview {
    CreateGroupView()
        .preferredColorScheme(.dark)
}