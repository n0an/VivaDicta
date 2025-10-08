# Feature Planning Prompt

You are helping plan a new feature for VivaDicta, an iOS voice transcription app. Please analyze the requested feature and provide a comprehensive implementation plan.

## Context
VivaDicta is built with:
- Swift 6.0 with strict concurrency
- SwiftUI + SwiftData for UI and persistence
- On-device transcription (WhisperKit and Parakeet) and cloud transcription services
- AVFoundation for audio recording
- iOS 18+ deployment target

## Current Architecture
- **AppState**: Observable app-wide state management
- **TranscriptionService Protocol**: Abstraction for different backends
- **SwiftData models**: Persistent storage with Transcription entity
- **TabBarView**: Main navigation (Record, Transcriptions, Models, Settings)

## Planning Template

For the requested feature, provide:

### 1. Feature Overview
- Brief description of what the feature does
- User stories/use cases
- How it fits into the existing app flow

### 2. Technical Implementation
- Required new models/data structures
- UI components needed (SwiftUI views)
- Service layer changes
- Integration points with existing code

### 3. Architecture Considerations  
- Thread safety and Swift concurrency patterns
- State management updates (AppState changes)
- SwiftData schema modifications if needed
- Error handling strategy

### 4. Implementation Steps
- Ordered list of development tasks
- Dependencies between tasks
- Estimated complexity (Small/Medium/Large)

### 5. Testing Strategy
- Unit tests needed
- UI tests for user flows
- Edge cases to consider

### 6. Potential Challenges
- Technical risks or unknowns
- Performance considerations
- Compatibility concerns

Please provide a detailed plan following this template for the requested feature.