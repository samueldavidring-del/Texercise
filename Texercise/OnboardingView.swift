import SwiftUI
import FamilyControls

struct OnboardingView: View {
    @EnvironmentObject var healthStore: HealthStore
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var familyControlsManager = FamilyControlsManager.shared
    
    @State private var currentStep = 0
    @State private var healthAuthorized = false
    @State private var familyControlsAuthorized = false
    @State private var showingAppPicker = false
    
    private let hasOnboardedKey = "hasCompletedOnboarding"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color(.systemGray4))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 24)
                
                TabView(selection: $currentStep) {
                    // MARK: Step 0 - Welcome
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 12) {
                            Text("Welcome to Texercise")
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            
                            Text("Earn points by staying active. Spend points on screen time. Stay accountable.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation { currentStep = 1 }
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                    }
                    .tag(0)
                    
                    // MARK: Step 1 - Health Access
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                        
                        VStack(spacing: 12) {
                            Text("Connect Health Data")
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            
                            Text("Texercise reads your steps, workouts and activity from Apple Health to award points automatically.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 12) {
                            if healthAuthorized {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Health access granted")
                                        .foregroundColor(.green)
                                }
                                
                                Button {
                                    withAnimation { currentStep = 2 }
                                } label: {
                                    Text("Continue")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            } else {
                                Button {
                                    healthStore.requestAuthorization()
                                    // Check after a short delay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        healthAuthorized = healthStore.isAuthorized
                                        if healthAuthorized {
                                            withAnimation { currentStep = 2 }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "heart.fill")
                                        Text("Grant Health Access")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                
                                Button {
                                    withAnimation { currentStep = 2 }
                                } label: {
                                    Text("Skip for now")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                    }
                    .tag(1)
                    
                    // MARK: Step 2 - Family Controls / App Tracking
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "iphone.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.purple)
                        
                        VStack(spacing: 12) {
                            Text("Choose Apps to Track")
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            
                            Text("Select which apps count against your points. Apps you haven't earned through activity will be restricted.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 12) {
                            if familyControlsManager.isAuthorized {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Screen Time access granted")
                                        .foregroundColor(.green)
                                }
                                
                                Button {
                                    showingAppPicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: "square.grid.2x2")
                                        Text("Choose Apps")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                
                                Button {
                                    completeOnboarding()
                                } label: {
                                    Text("Done")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            } else {
                                Button {
                                    Task {
                                        await familyControlsManager.requestAuthorization()
                                        familyControlsAuthorized = familyControlsManager.isAuthorized
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "lock.shield.fill")
                                        Text("Grant Screen Time Access")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                
                                Button {
                                    completeOnboarding()
                                } label: {
                                    Text("Skip for now")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
            .navigationBarHidden(true)
            .familyActivityPicker(
                isPresented: $showingAppPicker,
                selection: Binding(
                    get: { ScreenTimeCategoryStore.shared.activitySelection },
                    set: { ScreenTimeCategoryStore.shared.activitySelection = $0 }
                )
            )
            .onAppear {
                healthAuthorized = healthStore.isAuthorized
                familyControlsAuthorized = familyControlsManager.isAuthorized
            }
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: hasOnboardedKey)
        dismiss()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(HealthStore())
}
