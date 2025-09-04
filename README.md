# Tibiainfo

A modern iOS application for looking up Tibia character information. Built with SwiftUI, this app provides a clean and intuitive interface for exploring character data from the popular MMORPG Tibia.

## Features

### 🔍 Character Search
- Search for any Tibia character by name
- Real-time input validation following Tibia naming conventions
- Smart character name formatting and encoding

### 📊 Character Information
- **Basic Info**: Level, vocation, sex, world, residence
- **Status**: Online/offline indicator with real-time updates
- **Achievement Points**: Track character progression
- **Account Status**: Premium/free account information
- **Last Login**: Formatted date and time display

### ⚔️ Combat Data
- **Recent Deaths**: View character death history with levels and reasons
- **Achievements**: Browse recent achievements with grades and secret indicators

### 👥 Account Overview
- **Account Information**: Creation date and loyalty title
- **Other Characters**: List all characters on the same account
- **Guild Information**: Guild name and rank (if applicable)

### 🏠 Additional Features
- **Houses**: View owned properties with payment status
- **Marriage Status**: Display married character information
- **Former Names/Worlds**: Track character history
- **Unlocked Titles**: Count of available character titles

### 💾 Smart Caching & Storage
- **Recent Searches**: Quick access to previously searched characters
- **Offline Support**: Cached data available when network is unavailable
- **Intelligent Caching**: 1-minute cache timeout with 50-character limit

### 📱 User Experience
- **Responsive Design**: Optimized layouts for iPhone and iPad
- **Share Functionality**: Export character information as images
- **Loading States**: Smooth animations and progress indicators
- **Error Handling**: Comprehensive network and data error management

## Requirements

- **iOS**: 15.0 or later
- **Devices**: iPhone, iPad
- **Network**: Internet connection required for character lookups
- **Storage**: Minimal storage for caching recent searches

## Installation

### Prerequisites
- Xcode 14.0 or later
- iOS 15.0+ deployment target
- Apple Developer account (for device installation)

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/vini-ro/Tibiainfo.git
   ```

2. Open the project:
   ```bash
   cd Tibiainfo
   open Tibiainfo.xcodeproj
   ```

3. Build and run:
   - Select your target device or simulator
   - Press `Cmd + R` to build and run

## Usage

### Basic Character Search
1. Launch the app
2. Enter a character name in the search field
3. Tap "Search" or press Enter
4. View comprehensive character information

### Advanced Features
- **Recent Searches**: Tap any recent search to quickly reload character data
- **Share Information**: Use the share button (top-right) to export character data as an image
- **Offline Browsing**: Previously searched characters remain available offline
- **Clear Search**: Tap the 'X' button to clear current search and start fresh

### Input Validation
The app automatically validates character names according to Tibia rules:
- 2-29 characters in length
- Letters, spaces, and hyphens only
- No leading/trailing hyphens
- No double spaces or double hyphens

## API Integration

This app integrates with the [TibiaData API v4](https://tibiadata.com/) for character information:

### Endpoint
```
https://api.tibiadata.com/v4/character/{character_name}
```

### Features
- **Automatic URL Encoding**: Handles special characters in names
- **Rate Limiting**: Respectful API usage with caching
- **Error Handling**: Graceful handling of API errors and timeouts
- **Network Monitoring**: Automatic offline detection

### Data Structure
The app parses comprehensive character data including:
- Character basic information
- Death history
- Achievement records  
- Account information
- Guild membership
- House ownership
- Related characters

## Architecture

### SwiftUI + MVVM Pattern
- **Views**: SwiftUI-based user interface components
- **ViewModels**: ObservableObject classes managing state and business logic
- **Models**: Codable structs for API data representation

### Key Components

#### `ContentView.swift`
- Main interface with search functionality
- Responsive layout handling for different screen sizes
- Share functionality implementation

#### `CharacterViewModel.swift`
- Core business logic and data management
- Network request handling with Combine framework
- Caching and recent searches management
- Error handling and validation

#### `CharacterInfo.swift`
- Complete data model structures for API responses
- Nested structs for organized data representation

#### `OrientationManager.swift`
- Device orientation management utilities

### Caching Strategy
- **NSCache**: Memory-based caching with size limits
- **UserDefaults**: Persistent storage for recent searches
- **Timeout Management**: 1-minute cache validity
- **Memory Management**: Automatic cleanup and size limits

## Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on multiple devices
5. Submit a pull request

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Maintain consistent formatting
- Add comments for complex logic

### Testing
- Test on both iPhone and iPad
- Verify offline functionality
- Test with various character names
- Validate error scenarios

## License

This project is created by Vinicius Oliveira. Please respect the intellectual property and usage rights.

## Acknowledgments

- **TibiaData API**: For providing the character data service
- **Tibia**: The original MMORPG by CipSoft GmbH
- **SwiftUI Community**: For inspiration and best practices

## Author

**Vinicius Oliveira**
- Project Creation: August 24, 2024
- GitHub: [@vini-ro](https://github.com/vini-ro)

---

Made with ❤️ for the Tibia community