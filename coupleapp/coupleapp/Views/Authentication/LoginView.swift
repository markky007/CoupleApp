import SwiftUI

/// Login screen for existing users
struct LoginView: View {
    
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Form
                    formSection
                    
                    // Actions
                    actionSection
                    
                    // Navigation
                    navigationSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .navigationTitle("Welcome Back")
            .navigationBarTitleDisplayMode(.large)
            .disabled(viewModel.isLoading)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.pink.gradient)
            
            Text("Couple Quest")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            
            Text("Track chores, earn rewards together")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 16)
    }
    
    private var formSection: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("your@email.com", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                SecureField("Enter your password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        Task {
                            await viewModel.signIn()
                        }
                    }
            }
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            // Sign in button
            Button {
                Task {
                    await viewModel.signIn()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(viewModel.canSignIn ? Color.pink : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!viewModel.canSignIn || viewModel.isLoading)
            
            // Forgot password
            NavigationLink {
                ForgotPasswordView()
            } label: {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .foregroundColor(.pink)
            }
        }
    }
    
    private var navigationSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)
            
            HStack {
                Text("Don't have an account?")
                    .foregroundColor(.secondary)
                
                NavigationLink {
                    SignUpView()
                } label: {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                        .foregroundColor(.pink)
                }
            }
            .font(.subheadline)
        }
    }
}

#Preview {
    LoginView()
}
