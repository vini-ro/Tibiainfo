//
//  ContentView.swift
//  Tibiainfo
//
//  Created by Vinicius Oliveira on 24/08/24.
//

import SwiftUI

// ContentView
struct ContentView: View {
    @StateObject private var viewModel = CharacterViewModel()
    @State private var characterName: String = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Title
                        Text("Tibia Character Info")
                            .font(.largeTitle)
                            .bold()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top)
                        
                        // Search Section
                        searchSection
                        
                        if let character = viewModel.characterInfo {
                            if horizontalSizeClass == .regular {
                                // Landscape layout for iPad and larger screens
                                HStack(alignment: .top, spacing: 20) {
                                    VStack {
                                        characterInfoSection(character)
                                        if let accountInfo = viewModel.accountInfo {
                                            accountInfoSection(accountInfo)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack {
                                        if !viewModel.deaths.isEmpty {
                                            deathsSection
                                        }
                                        if !viewModel.achievements.isEmpty {
                                            achievementsSection
                                        }
                                        if !viewModel.otherCharacters.isEmpty {
                                            otherCharactersSection
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            } else {
                                // Portrait layout for iPhone and smaller screens
                                characterInfoSection(character)
                                
                                if !viewModel.deaths.isEmpty {
                                    deathsSection
                                }
                                
                                if !viewModel.achievements.isEmpty {
                                    achievementsSection
                                }
                                
                                if let accountInfo = viewModel.accountInfo {
                                    accountInfoSection(accountInfo)
                                }
                                
                                if !viewModel.otherCharacters.isEmpty {
                                    otherCharactersSection
                                }
                            }
                        } else if let errorMessage = viewModel.errorMessage {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        // Recent Searches Section
                        if !viewModel.recentSearches.isEmpty {
                            recentSearchesSection
                        }
                    }
                    .padding()
                }
                .toolbar {
                    if viewModel.characterInfo != nil {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                prepareShare()
                            }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    if let image = shareImage {
                        ShareSheet(items: [image])
                    }
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    ZStack {
                        Color(.systemBackground)
                            .opacity(0.8)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.accentColor)
                            
                            Text("Loading...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 120, height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
                        )
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    .zIndex(2)
                }
            }
            .navigationBarHidden(false)
        }
    }
    
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Character Name", text: $characterName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .onChange(of: characterName) { _, newValue in
                        // Only validate input, don't search
                        if newValue.count > 29 {
                            characterName = String(newValue.prefix(29))
                        }
                        // Remove invalid characters in real-time
                        characterName = newValue.filter { 
                            $0.isLetter || $0 == "-" || $0 == " "
                        }
                    }
                    .onSubmit {
                        performSearch()
                    }
                    .overlay(
                        Group {
                            if !characterName.isEmpty {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        resetView()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray.opacity(0.6))
                                            .font(.system(size: 16))
                                    }
                                    .padding(.trailing, 8)
                                }
                            }
                        }
                    )
                    .frame(height: 44)
            }
            
            Button(action: {
                performSearch()
            }) {
                Text("Search")
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .font(.headline)
            }
        }
        .padding(.horizontal)
    }
    
    private func performSearch() {
        hideKeyboard()
        viewModel.fetchCharacterInfo(name: characterName)
    }
    
    private func resetView() {
        characterName = ""
        viewModel.clearCurrentSearch()
        hideKeyboard()
    }
    
    private func characterInfoSection(_ character: CharacterInfo.CharacterData.Character) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(character.name)
                    .font(.title)
                    .bold()
                    .minimumScaleFactor(0.75)
                
                Spacer()
                
                // Online status indicator
                let isOnline = viewModel.otherCharacters.first { 
                    $0.name.lowercased() == character.name.lowercased() 
                }?.status.lowercased() == "online"
                
                Circle()
                    .fill(isOnline ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .shadow(radius: 2)
            }
            
            // Only show title if it exists and isn't empty
            if let title = character.title, !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                // Get status from otherCharacters
                let status = viewModel.otherCharacters.first { 
                    $0.name.lowercased() == character.name.lowercased() 
                }?.status ?? "Offline"
                InfoRow(label: "Status", value: status)
                InfoRow(label: "Level", value: "\(character.level)")
                InfoRow(label: "Sex", value: character.sex)
                InfoRow(label: "Vocation", value: character.vocation)
                InfoRow(label: "World", value: character.world)
                InfoRow(label: "Achievement Points", value: "\(character.achievement_points)")
                InfoRow(label: "Residence", value: character.residence)
                
                if let lastLogin = character.last_login {
                    InfoRow(label: "Last Login", value: lastLogin.formatTibiaDate())
                }
                
                InfoRow(label: "Account Status", value: character.account_status)
                
                if let marriedTo = character.married_to {
                    InfoRow(label: "Married to", value: marriedTo)
                }
                
                InfoRow(label: "Unlocked Titles", value: "\(character.unlocked_titles)")
                
                if let guild = character.guild {
                    InfoRow(label: "Guild", value: guild.name)
                    InfoRow(label: "Guild Rank", value: guild.rank)
                }
                
                if let houses = character.houses, !houses.isEmpty {
                    Text("Houses")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    ForEach(houses, id: \.houseid) { house in
                        VStack(alignment: .leading, spacing: 4) {
                            InfoRow(label: "Name", value: house.name)
                            InfoRow(label: "Town", value: house.town)
                            InfoRow(label: "Paid Until", value: house.paid)
                        }
                        .padding(.leading)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var deathsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Deaths")
                .font(.headline)
            
            ForEach(viewModel.deaths, id: \.time) { death in
                VStack(alignment: .leading) {
                    Text("Level \(death.level)")
                        .font(.subheadline)
                    Text(death.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private func accountInfoSection(_ accountInfo: CharacterInfo.CharacterData.AccountInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account Information")
                .font(.headline)
            
            if let created = accountInfo.created {
                InfoRow(label: "Created", value: created)
            }
            
            if let loyaltyTitle = accountInfo.loyalty_title {
                InfoRow(label: "Loyalty Title", value: loyaltyTitle)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var otherCharactersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other Characters")
                .font(.headline)
            
            ForEach(viewModel.otherCharacters, id: \.name) { character in
                VStack(alignment: .leading) {
                    Text(character.name)
                        .font(.subheadline)
                    Text("\(character.world) - \(character.status)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Searches")
                .font(.headline)
            
            ForEach(viewModel.recentSearches) { search in
                Button(action: {
                    characterName = search.name
                    viewModel.fetchCharacterInfo(name: search.name, fromRecentSearch: true)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(search.name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Text("\(search.vocation) - Level \(search.level)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("World: \(search.world)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Last updated: \(search.formattedDate)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Achievements")
                .font(.headline)
            
            ForEach(viewModel.achievements, id: \.name) { achievement in
                VStack(alignment: .leading) {
                    HStack {
                        Text(achievement.name)
                            .font(.subheadline)
                        if achievement.secret {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    Text("Grade \(achievement.grade)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private func prepareShare() {
        // Create a VStack with all the content we want to share
        let contentToShare = VStack(spacing: 20) {
            if let character = viewModel.characterInfo {
                characterInfoSection(character)
                
                if !viewModel.deaths.isEmpty {
                    deathsSection
                }
                
                if !viewModel.achievements.isEmpty {
                    achievementsSection
                }
                
                if let accountInfo = viewModel.accountInfo {
                    accountInfoSection(accountInfo)
                }
                
                if !viewModel.otherCharacters.isEmpty {
                    otherCharactersSection
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        
        // Convert the view to an image
        shareImage = contentToShare.snapshot()
        showingShareSheet = true
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundColor(.secondary)
                .font(.body)
            Spacer()
            Text(value)
                .bold()
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .frame(height: 32)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#Preview {
    ContentView()
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    func snapshot() -> UIImage {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension String {
    func formatTibiaDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // First try the ISO format
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = dateFormatter.date(from: self) {
            dateFormatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
            dateFormatter.dateFormat = "dd/MM/yyyy HH:mm BRT"
            return dateFormatter.string(from: date)
        }
        
        // If ISO format fails, try parsing the existing format
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm 'in the afternoon'"
        if let date = dateFormatter.date(from: self) {
            dateFormatter.timeZone = TimeZone(identifier: "America/Sao_Paulo")
            dateFormatter.dateFormat = "dd/MM/yyyy HH:mm BRT"
            return dateFormatter.string(from: date)
        }
        
        // Return original string if parsing fails
        return self
    }
}
