<!--
Downloaded via https://llm.codes by @steipete on January 11, 2026 at 05:42 PM
Source URL: https://developer.apple.com/events/resources/code-along-205/
Total pages processed: 1
URLs filtered: Yes
Content de-duplicated: Yes
Availability strings filtered: Yes
Code blocks only: No
-->

# https://developer.apple.com/events/resources/code-along-205/

View in English

# Foundation Models Code-Along Instructions

In this code-along session, you’ll gain practical experience using the Foundation Models framework to integrate Apple’s on-device large language model (LLM) into an application. You’ll build generative AI features into a sample app directly within Xcode, exploring core capabilities such as text generation, structured data output, streaming, and tool calling.

This guide is designed to be used in conjunction with the live coding demonstration. Each chapter provides **Playground** snippets for isolated experimentation, **App** steps for extending the starter Xcode project, and **Model** definitions for custom types and tools. As the instructor demonstrates, use the playground code to explore the APIs, then implement the App steps to integrate these features into SwiftUI views and view models. By the end of this session, you’ll have a fully functional app and a solid understanding of how to incorporate Foundation Models into your own projects.

## Prerequisites Heading self-link

Complete the following steps to prepare your environment for the code-along.

### 1\. Download the Xcode project Heading self-link

Begin by downloading the necessary project files.

- Download the project zip file
- After downloading, unzip the file. You’ll find the folder named `FoundationModelsCodeAlong`. This is the starter project for this code-along. It contains the necessary views, models, and placeholder code.

### 2\. Configure Code Signing Heading self-link

Next, open the starter project and configure code signing.

1. Open the `FoundationModelsCodeAlong` project in Xcode.
2. In the Project Navigator, select the project file (the top-level blue icon).
3. Click on the `FoundationModelsCodeAlong` target.
4. Navigate to the **Signing & Capabilities** tab.
5. From the “Team” dropdown menu, select your developer team.

### 3\. Build and Run the App (⌘+R) Heading self-link

Verify that your setup is correct by building and running the app.

- Select **My Mac** as the run destination in the Xcode toolbar.
- Press **Command-R (⌘+R)** to build and run the app.

The sample app should launch, displaying a list of featured landmarks. This is the starting point for adding generative features during the session.

## Chapter 1: Foundation Models framework basics Heading self-link

This chapter introduces the fundamentals of using the Foundation Models framework to generate text. You’ll explore basic text generation, guiding the model with instructions, and handling model availability.

#### 1.1: Making your first generation request Heading self-link

This playground demonstrates the basic process of generating text from a simple prompt.

**Copy this code into `Playground.swift`:**

```swift
import FoundationModels
import Playgrounds

#Playground {
// Create a new session with the language model.
let session = LanguageModelSession()

// Asynchronously generate a response from a text prompt.
let response = try await session.respond(to: "Generate a 3-day itinerary to Paris.")
}

Copy

#### 1.2: Guiding the model with instructions Heading self-link

While a simple prompt can be effective, using instructions allows you to define a persona, set rules, and specify the desired format. This results in more consistent and higher-quality output. This section demonstrates how to initialize a `LanguageModelSession` with instructions that guide its behavior for all subsequent prompts within that session.

**Add this new playground block to your file:**

```swift
#Playground {
let instructions = """
Your job is to create an itinerary for the user.
Each day needs an activity, hotel and restaurant.

Always include a title, a short description, and a day-by-day plan.
"""

let session = LanguageModelSession(instructions: instructions)
let response = try await session.respond(to: "Generate a 3-day itinerary to Paris.")
}

#### 1.3: Handling model availability Heading self-link

Your app may run on devices where the on-device model is unavailable. It’s important to check for model availability and provide a graceful fallback.

**Add this playground block to your file:**

#Playground {
```swift
let model = SystemLanguageModel.default

// The availability property provides detailed information on the model's state.
switch model.availability {
case .available:
print("Foundation Models is available and ready to go!")

case .unavailable(.deviceNotEligible):
print("The model is not available on this device.")

case .unavailable(.appleIntelligenceNotEnabled):
print("Apple Intelligence is not enabled in Settings.")

case .unavailable(.modelNotReady):
print("The model is not ready yet. Please try again later.")

case .unavailable(let other):
print("The model is unavailable for an unknown reason.")
}
}

### App: Building the foundation and seeing first results Heading self-link

Apply the core concepts you’ve learned by adding an availability check, creating a `ViewModel` to manage the session, and calling the model to display the raw text output in your app.

#### 1.4: Handle availability in the view Heading self-link

Open **`Views/1-LandmarkDetailView.swift`**. Replace the placeholder `Text` view with a check for model availability.

1. Next, inside the `LandmarkDetailView` struct, create an instance of the system’s default language model.

```swift
// MARK: - [CODE-ALONG] Chapter 1.4.1: Add a model instance
private let model = SystemLanguageModel.default

2. Delete the placeholder availability enum.

```swift
// MARK: - [CODE-ALONG] Chapter 1.4.2: Remove placeholder availability
private enum Availability { case available, unavailable }
private let availability: Availability = .available

3. Replace the `switch` statement `availability` with `model.availability`. Replace:

```swift
// MARK: - [CODE-ALONG] Chapter 1.4.3: Replace availability with model.availability
switch availability

With:

```swift
switch model.availability

Show the updated Views/1-LandmarkDetailView.swift

```swift
import FoundationModels
import SwiftUI

struct LandmarkDetailView: View {
let landmark: Landmark

private let model = SystemLanguageModel.default

var body: some View {
switch model.availability {
case .available:
LandmarkTripView(landmark: landmark)

case .unavailable(.appleIntelligenceNotEnabled):
MessageView(
landmark: self.landmark,
message: """
Trip Planner is unavailable because \
Apple Intelligence has not been turned on.
"""
)
default:
MessageView(
landmark: self.landmark,
message: """
Trip Planner is unavailable. Try again later.
"""
)
}
}
}

#### 1.5: Create the itinerary generator Heading self-link

Open **`ViewModels/ItineraryGenerator.swift`**. This file already contains some starter code.

1. Inside the class, add a private property to hold the **`LanguageModelSession`**.

```swift
// MARK: - [CODE-ALONG] Chapter 1.5.1: Add a session property
private var session: LanguageModelSession

2. Update the **initializer** by adding instructions for the model and initializing the `LanguageModelSession`.

```swift
// MARK: - [CODE-ALONG] Chapter 1.5.2: Initialize LanguageModelSession
let instructions = """
Your job is to create an itinerary for the user.
Each day needs an activity, hotel and restaurant.

Always include a title, a short description, and a day-by-day plan.
"""
self.session = LanguageModelSession(instructions: instructions)

3. Update the placeholder asynchronous `generateItinerary` function so it can be invoked to generate itineraries and store the result in `itineraryContent`.

```swift
// MARK: - [CODE-ALONG] Chapter 1.5.3: Add itinerary generator using Foundation Models
do {
let prompt = "Generate a \(dayCount)-day itinerary to \(landmark.name)."
let response = try await session.respond(to: prompt)
self.itineraryContent = response.content
} catch {
self.error = error
}

Show the updated ViewModels/ItineraryGenerator.swift

```swift
import Foundation
import FoundationModels
import Observation

@Observable
@MainActor
final class ItineraryGenerator {

var error: Error?
let landmark: Landmark

private var session: LanguageModelSession

// MARK: - [CODE-ALONG] Chapter 2.3.1: Update to Generable
// MARK: - [CODE-ALONG] Chapter 4.1.1: Change the property to hold a partially generated Itinerary
private(set) var itineraryContent: String?

// MARK: - [CODE-ALONG] Chapter 5.3.1: Add a property to hold the tool

init(landmark: Landmark) {
self.landmark = landmark
let instructions = """
Your job is to create an itinerary for the user.
Each day needs an activity, hotel and restaurant.

Always include a title, a short description, and a day-by-day plan.
"""
self.session = LanguageModelSession(instructions: instructions)

// MARK: - [CODE-ALONG] Chapter 5.3.2: Initialize LanguageModelSession with Tool

}

func generateItinerary(dayCount: Int = 3) async {
do {
let prompt = "Generate a \(dayCount)-day itinerary to \(landmark.name)."
let response = try await session.respond(to: prompt)
self.itineraryContent = response.content
} catch {
self.error = error
}

// MARK: - [CODE-ALONG] Chapter 2.3.2: Update to use Generables
// MARK: - [CODE-ALONG] Chapter 3.3: Update to use one-shot prompting
// MARK: - [CODE-ALONG] Chapter 4.1.2: Update to use streaming API
// MARK: - [CODE-ALONG] Chapter 5.3.1: Update the instructions to use the Tool
// MARK: - [CODE-ALONG] Chapter 5.3.2: Update the LanguageModelSession with the tool
// MARK: - [CODE-ALONG] Chapter 6.2.1: Update to exclude schema in prompt

func prewarmModel() {
// MARK: - [CODE-ALONG] Chapter 6.1.1: Add a function to pre-warm the model
}
}

#### 1.6: Update the view to display text output Heading self-link

Open **`Views/2-LandmarkTripView.swift`**. You’ll connect this view to the new `ItineraryGenerator`.

1. Declare a local property that holds an instance of `ItineraryGenerator`.

```swift
// MARK: - [CODE-ALONG] Chapter 1.6.1: Add a local variable of type `ItineraryGenerator`
@State private var itineraryGenerator: ItineraryGenerator?

2. Create an instance of the `ItineraryGenerator` when the view appears using the `.task` modifier.

```swift
// MARK: - [CODE-ALONG] Chapter 1.6.2: Create the generator when the view appears
let generator = ItineraryGenerator(landmark: landmark)
self.itineraryGenerator = generator

3. Replace the `EmptyView()` in the `ScrollView``else {}` block with logic to display the generated content.

```swift
// MARK: - [CODE-ALONG] Chapter 1.6.3: Replace EmptyView with model output
else if let content = itineraryGenerator?.itineraryContent {
Text(LocalizedStringKey(content))
.padding()
}

4. Make the “Generate Itinerary” button appear by commenting out the `.hidden()` view modifier.

```swift
ItineraryButton {
requestedItinerary = true
// MARK: - [CODE-ALONG] Chapter 1.6.4: Generate itinerary
await itineraryGenerator?.generateItinerary()
}
// MARK: - [CODE-ALONG] Chapter 1.6.4: Show the button
//.hidden()

Show the updated Views/2-LandmarkTripView.swift

```swift
import SwiftUI

struct LandmarkTripView: View {
let landmark: Landmark

@State private var itineraryGenerator: ItineraryGenerator?

@State private var requestedItinerary: Bool = false

var body: some View {
ScrollView {
if !requestedItinerary {
VStack(alignment: .leading, spacing: 16) {
Text(landmark.name)
.padding(.top, 150)
.font(.largeTitle)
.fontWeight(.bold)

Text(landmark.shortDescription)
}
.padding(.horizontal)
.frame(maxWidth: .infinity, alignment: .leading)
}
// MARK: - [CODE-ALONG] Chapter 2.4: Update the Text view with `ItineraryView`
else if let content = itineraryGenerator?.itineraryContent {
Text(LocalizedStringKey(content))
.padding()
}

}
.scrollDisabled(!requestedItinerary)
.safeAreaInset(edge: .bottom) {
ItineraryButton {
requestedItinerary = true
await itineraryGenerator?.generateItinerary()
}

}
.task {
let generator = ItineraryGenerator(landmark: landmark)
self.itineraryGenerator = generator

// MARK: - [CODE-ALONG] Chapter 6.1.2: Pre-warm the model when the view appears

}
.headerStyle(landmark: landmark)
}

**Build and Run the App (⌘+R):** You now have a working end-to-end feature! Tapping “Generate Itinerary” displays a loading indicator and then displays the generated text.

## Chapter 2: Generating structured outputs Heading self-link

This chapter explores how to generate structured data, such as Swift structs, using the Foundation Models framework. This enables type-safe and predictable results for your generative AI features.

#### 2.1: Generating simple structured output Heading self-link

Generating raw text from the model can be useful, but getting structured data like a Swift `struct` unlocks powerful possibilities. This allows for type-safe, predictable results.

This section demonstrates how to use the `@Generable` macro to define a simple Swift type that the language model can generate.

**Copy this block into `Playground.swift`:**

#Playground {
let instructions = """
Your job is to create an itinerary for the user.
"""

let session = LanguageModelSession(instructions: instructions)
let prompt = "Generate a 3-day itinerary to Paris."
let response = try await session.respond(to: prompt,
generating: SimpleItinerary.self)
}

// The @Generable macro makes your custom type compatible with the model.
@Generable
struct SimpleItinerary {
// The @Guide macro provides hints to the model about a property.
@Guide(description: "An exciting name for the trip.")
let title: String

@Guide(description: "A short, engaging description of the trip.")
let description: String

@Guide(description: "A list of day-by-day plans, as simple strings.")
@Guide(.count(3))
let days: [String]
}

#### 2.2: Generating nested structured output Heading self-link

You can create complex data structures by nesting `@Generable` types. This allows you to define a rich data model that the language model can populate.

Learn how to define and generate complex, nested Swift types by composing multiple `@Generable` structs and enums.

**Add this block to `Playground.swift`:**

#Playground {
```swift
let instructions = """
Your job is to create an itinerary for the user.
"""

let session = LanguageModelSession(instructions: instructions)
let prompt = "Generate a 3-day itinerary to the Grand Canyon."
let response = try await session.respond(to: prompt,
generating: Itinerary.self)
}

### App: Modeling and displaying the structured itinerary Heading self-link

Refactor the app to use structured outputs. Define the app’s `Itinerary` model and update the `ViewModel` and `View` to generate and display it.

#### 2.3: Refactoring the itinerary generator Heading self-link

Open **`ViewModels/ItineraryGenerator.swift`**. You’ll update it to generate our new `Itinerary` struct instead of a raw `String`.

1. Change the type of `itineraryContent` to our new `Itinerary` struct and rename it to `itinerary`.

```swift
// MARK: - [CODE-ALONG] Chapter 2.3.1: Update to Generable
private(set) var itinerary: Itinerary?

2. Update the `generateItinerary` function to request the `Itinerary.self` type from the model.

```swift
// MARK: - [CODE-ALONG] Chapter 2.3.2: Update to use Generables
let response = try await session.respond(to: prompt,
generating: Itinerary.self)
self.itinerary = response.content

3. Simplify instructions by removing structural guidance

```swift
// MARK: - [CODE-ALONG] Chapter 2.3.3: Update instructions to remove structural guidance
let instructions = """
Your job is to create an itinerary for the user.
Each day needs an activity, hotel and restaurant.
"""

// MARK: - [CODE-ALONG] Chapter 4.1.1: Change the property to hold a partially generated Itinerary
private(set) var itinerary: Itinerary?

init(landmark: Landmark) {
self.landmark = landmark
let instructions = """
Your job is to create an itinerary for the user.
Each day needs an activity, hotel and restaurant.
"""
self.session = LanguageModelSession(instructions: instructions)

func generateItinerary(dayCount: Int = 3) async {
do {
let prompt = "Generate a \(dayCount)-day itinerary to \(landmark.name)."
let response = try await session.respond(to: prompt,
generating: Itinerary.self)
self.itinerary = response.content
} catch {
self.error = error
}
// MARK: - [CODE-ALONG] Chapter 3.3: Update to use one-shot prompting
// MARK: - [CODE-ALONG] Chapter 4.1.2: Update to use streaming API
// MARK: - [CODE-ALONG] Chapter 5.3.1: Update the instructions to use the Tool
// MARK: - [CODE-ALONG] Chapter 5.3.2: Update the LanguageModelSession with the tool
// MARK: - [CODE-ALONG] Chapter 6.2.1: Update to exclude schema in prompt

#### 2.4: Updating the views to display the structured data Heading self-link

The starter project includes a view in `Views/3-ItineraryView.swift` that renders the structured output from the model.

Open **`Views/2-LandmarkTripView.swift`**. You’ll update `LandmarkTripView` to render this view instead of the text string output.

Update `itineraryContent` to `itinerary` and replace `Text()` with a call to `ItineraryView`.

```swift
// MARK: - [CODE-ALONG] Chapter 2.4: Update the Text view with `ItineraryView`
else if let itinerary = itineraryGenerator?.itinerary {
ItineraryView(landmark: landmark, itinerary: itinerary).padding()
}

Text(landmark.shortDescription)
}
.padding(.horizontal)
.frame(maxWidth: .infinity, alignment: .leading)
}
else if let itinerary = itineraryGenerator?.itinerary {
ItineraryView(landmark: landmark, itinerary: itinerary).padding()
}

**Build and Run the App (⌘+R):** The app now generates a full `Itinerary` object and displays it in a formatted, custom view.

## Chapter 3: Prompting techniques Heading self-link

This chapter explores techniques to improve the accuracy and consistency of the model’s output using advanced prompting strategies.

#### 3.1: Building prompts with PromptBuilder Heading self-link

As prompts become more complex, the `@PromptBuilder` allows you to dynamically construct your prompt using Swift syntax like `if` statements and loops.

#Playground {
let instructions = "Your job is to create an itinerary for the user."
let session = LanguageModelSession(instructions: instructions)

let kidFriendly = true

// The Prompt builder allows for conditional logic.
let prompt = Prompt {
"Generate a 3-day itinerary to the Grand Canyon."
if kidFriendly {
"The itinerary must be kid-friendly."
}
}

let response = try await session.respond(to: prompt,
generating: Itinerary.self)
}

#### 3.2: One-shot prompting Heading self-link

You can significantly improve the quality and reliability of the model’s output by providing one or more high-quality examples of the desired output directly in the prompt. This technique is known as “few-shot prompting.” Learn how to construct a `Prompt` that includes both your request and a complete example.

#Playground {
```swift
let instructions = "Your job is to create an itinerary for the user."
let session = LanguageModelSession(instructions: instructions)

let kidFriendly = false

// Use the Prompt builder to combine your request with an example.
let prompt = Prompt {
"Generate a 3-day itinerary to the Grand Canyon."
if kidFriendly {
"The itinerary must be kid-friendly."
"Here is an example of the desired format, but don't copy its content:"
Itinerary.exampleTripToJapan
}
}

#### 3.3: Update the itinerary generator with the example Heading self-link

Open **`ViewModels/ItineraryGenerator.swift`** and modify the `generateItinerary` function to use the `Prompt {...}` builder syntax and include our new example.

**Update the `generateItinerary` function** to include one-shot prompting.

```swift
// MARK: - [CODE-ALONG] Chapter 3.3: Update to use one-shot prompting
let prompt = Prompt {
"Generate a \(dayCount)-day itinerary to \(landmark.name)."
"Give it a fun title and description."
"Here is an example of the desired format, but don't copy its content:"
Itinerary.exampleTripToJapan
}

init(landmark: Landmark) {
self.landmark = landmark
let instructions = Instructions {
"Your job is to create an itinerary for the user."
"For each day, you must suggest one hotel and one restaurant."
}
self.session = LanguageModelSession(instructions: instructions)

func generateItinerary(dayCount: Int = 3) async {
do {
let prompt = Prompt {
"Generate a \(dayCount)-day itinerary to \(landmark.name)."
"Give it a fun title and description."
"Here is an example of the desired format, but don't copy its content:"
Itinerary.exampleTripToJapan
}

let response = try await session.respond(to: prompt,
generating: Itinerary.self)
self.itinerary = response.content
} catch {
self.error = error
}
// MARK: - [CODE-ALONG] Chapter 3.3: Update to use one-shot prompting
// MARK: - [CODE-ALONG] Chapter 4.1.2: Update to use streaming API
// MARK: - [CODE-ALONG] Chapter 5.3.1: Update the instructions to use the Tool
// MARK: - [CODE-ALONG] Chapter 5.3.2: Update the LanguageModelSession with the tool
// MARK: - [CODE-ALONG] Chapter 6.2.1: Update to exclude schema in prompt

**Build and Run the App (⌘+R):** The app’s functionality will appear the same, but the quality and consistency of the generated itineraries should be significantly improved.

## Chapter 4: Streaming responses Heading self-link

This chapter demonstrates how to refactor the app to use the streaming API, providing a more engaging user experience by displaying the itinerary as it’s being generated.

### App: Building a streaming UI Heading self-link

This section focuses on implementing a streaming UI, skipping the playground examples as streaming is best demonstrated within the context of a full application.

#### 4.1: Update the itinerary generator for streaming Heading self-link

Open **`ViewModels/ItineraryGenerator.swift`**. You’ll modify the generation function to use the streaming API.

1. Update the `itinerary` property. Its type needs to be `Itinerary.PartiallyGenerated?` to support streaming data.

```swift
// MARK: - [CODE-ALONG] Chapter 4.1.1: Change the property to hold a partially generated Itinerary
private(set) var itinerary: Itinerary.PartiallyGenerated?

2. Update the `generateItinerary` function. Use `session.streamResponse` and loop over the results, updating our `itinerary` property with each new partial result.

**Replace:**

```swift
// MARK: - [CODE-ALONG] Chapter 4.1.2: Update to use streaming API
let response = try await session.respond(to: prompt,
generating: Itinerary.self)
self.itinerary = response.content

**With:**

```swift
let stream = session.streamResponse(to: prompt,
generating: Itinerary.self)
for try await partialResponse in stream {
self.itinerary = partialResponse.content
}

private(set) var itinerary: Itinerary.PartiallyGenerated?

func generateItinerary(dayCount: Int = 3) async {
do {
let prompt = Prompt {
"Generate a \(dayCount)-day itinerary to \(landmark.name)."
"Give it a fun title and description."
"Here is an example of the desired format, but don't copy its content:"
Itinerary.exampleTripToJapan
}
let stream = session.streamResponse(to: prompt,
generating: Itinerary.self)
for try await partialResponse in stream {
self.itinerary = partialResponse.content
}

} catch {
self.error = error
}
// MARK: - [CODE-ALONG] Chapter 5.3.1: Update the instructions to use the Tool
// MARK: - [CODE-ALONG] Chapter 5.3.2: Update the LanguageModelSession with the tool
// MARK: - [CODE-ALONG] Chapter 6.2.1: Update to exclude schema in prompt

#### 4.2: Updating views to render streaming content Heading self-link

First, open **`Views/3-ItineraryView.swift`**. You’ll update it to handle `PartiallyGenerated` content.

1. Update generables with `PartiallyGenerated`.

**Replace**

```swift
let itinerary: Itinerary
...
let plan: DayPlan
...
let activities: [Activity]
...

**With**:

```swift
let itinerary: Itinerary.PartiallyGenerated
...
let plan: DayPlan.PartiallyGenerated
...
let activities: [Activity].PartiallyGenerated

2. Unwrap the `Itinerary`, `DayPlan`, and `Activity` properties. For example, to access `itinerary.title`, unwrap it using `if let`.

```swift
// MARK: - [CODE-ALONG] Chapter 4.2.2: Update to unwrap all PartiallyGenerated types
Text(itinerary.title)
.contentTransition(.opacity)
.font(.largeTitle)
.fontWeight(.bold)

```swift
if let title = itinerary.title {
Text(title)
.contentTransition(.opacity)
.font(.largeTitle)
.fontWeight(.bold)
}

3. Repeat this for all properties:
- `Itinerary`: `title`, `description`, `rationale`
- `DayPlan`: `title`, `subtitle`, `destination`
- `Activity`: `title`, `description`

Show the updated Views/3-ItineraryView.swift

```swift
import FoundationModels
import SwiftUI
import MapKit

struct ItineraryView: View {
let landmark: Landmark
let itinerary: Itinerary.PartiallyGenerated

var body: some View {
VStack(alignment: .leading, spacing: 16) {
VStack(alignment: .leading) {
if let title = itinerary.title {
Text(title)
.contentTransition(.opacity)
.font(.largeTitle)
.fontWeight(.bold)
}
if let description = itinerary.description {
Text(description)
.contentTransition(.opacity)
.font(.subheadline)
.foregroundStyle(.secondary)
}
}
HStack(alignment: .top) {
Image(systemName: "sparkles")
if let rationale = itinerary.rationale {
Text(rationale)
.contentTransition(.opacity)
.rationaleStyle()
}
}

if let days = itinerary.days {
ForEach(days, id: \.title) { plan in
DayView(
landmark: landmark,
plan: plan
)
}
}
}
.animation(.easeOut, value: itinerary)
.itineraryStyle()
}
}

private struct DayView: View {
let landmark: Landmark
let plan: DayPlan.PartiallyGenerated

@State private var mapItem: MKMapItem?

var body: some View {
VStack(alignment: .leading, spacing: 16) {
ZStack(alignment: .bottom) {
LandmarkDetailMapView(
landmark: landmark,
landmarkMapItem: mapItem
)

.task(id: plan.destination) {
guard let destination = plan.destination, !destination.isEmpty else { return }

if let fetchedItem = await LocationLookup().mapItem(atLocation: destination) {
self.mapItem = fetchedItem
}
}

VStack(alignment: .leading) {

if let title = plan.title {
Text(title)
.contentTransition(.opacity)
.font(.headline)
}
if let subtitle = plan.subtitle {
Text(subtitle)
.contentTransition(.opacity)
.font(.subheadline)
.foregroundStyle(.secondary)
}
}
.padding(12)
.frame(maxWidth: .infinity, alignment: .leading)
.blurredBackground()
}
.clipShape(RoundedRectangle(cornerRadius: 12))
.frame(maxWidth: .infinity)
.frame(height: 200)
.padding([.horizontal, .top], 4)

ActivityList(activities: plan.activities ?? [])
.frame(maxWidth: .infinity, alignment: .leading)
.padding(.horizontal)
}
.padding(.bottom)
.geometryGroup()
.card()
.animation(.easeInOut, value: plan)
}

private struct ActivityList: View {
let activities: [Activity].PartiallyGenerated

var body: some View {
ForEach(activities) { activity in
HStack(alignment: .top, spacing: 12) {
if let title = activity.title {
ActivityIcon(symbolName: activity.type?.symbolName)
VStack(alignment: .leading) {
Text(title)
.contentTransition(.opacity)
.font(.headline)
if let description = activity.description {
Text(description)
.contentTransition(.opacity)
.font(.subheadline)
.foregroundStyle(.secondary)
}
}
}
}
}
}
}

**Build and Run the App (⌘+R):** This provides a more dynamic user experience. When you tap the button, you’ll see a planning screen, and then the full, detailed itinerary will appear piece-by-piece.

## Chapter 5: Tool calling Heading self-link

This chapter demonstrates how to extend the capabilities of the language model by providing it with `Tools`. A tool is a Swift function that the model can call to get information or perform an action.

#### 5.1: Building the `FindPointsOfInterestTool` Heading self-link

You can give the language model new capabilities by providing it with `Tools`. A tool is a Swift function that the model can decide to call to get information or perform an action, such as looking up real-time data from an API. Let’s build a tool that can find real points of interest.

Open **`ViewModels/FindPointsOfInterestTool.swift`**. You’ll implement the tool step-by-step.

1. Structs that conform to the `Tool` protocol must have a `name` and a `description`. The language model uses the `name` to call the tool and the `description` to understand what the tool does and when to use it.

```swift
// MARK: - [CODE-ALONG] Chapter 5.1.1: Define tool name and description
let name = "findPointsOfInterest"
let description = "Finds points of interest for a landmark."

2. Define the different types of places our tool can search for. A Swift `enum` marked with the `@Generable` macro is perfect for this, as it provides a list of valid, typed options for the model to choose from.

```swift
// MARK: - [CODE-ALONG] Chapter 5.1.2: Define searchable categories
@Generable
enum Category: String, CaseIterable {
case hotel
case restaurant
}

3. Define the tool’s `Arguments` struct. It defines the inputs the model needs to provide when it calls our tool. Mark it as `@Generable` and use the `@Guide` macro to give the model hints about each property.

```swift
// MARK: - [CODE-ALONG] Chapter 5.1.3: Define tool arguments
@Guide(description: "This is the type of business to look up for.")
let pointOfInterest: Category

4. Implement the tool’s call logic. The `call(arguments:)` function contains the core logic of the tool. It receives the arguments from the model, performs an action, and must return a `String` result. You’ll call a helper function to get mock data and format it into a user-friendly sentence.

```swift
// MARK: - [CODE-ALONG] Chapter 5.1.4: Implement the tool's call logic
let results = await getSuggestions(category: arguments.pointOfInterest,
landmark: landmark.name)
return """
There are these \(arguments.pointOfInterest) in \(landmark.name):
\(results.joined(separator: ", "))
"""

5. Implement the `getSuggestions()` function that provides our data. For this code-along, use a `switch` statement to return a hardcoded list of suggestions. In a real-world app, this is where you might make a call to MapKit APIs or other server-side APIs backed by a database.

```swift
// MARK: - [CODE-ALONG] Chapter 5.1.5: Provide mock data for suggestions
switch category {
case .hotel : ["Hotel 1", "Hotel 2", "Hotel 3"]
case .restaurant : ["Restaurant 1", "Restaurant 2", "Restaurant 3"]
}

Show the updated ViewModels/FindPointsOfInterestTool.swift

@Observable
final class FindPointsOfInterestTool: Tool {

let name = "findPointsOfInterest"
let description = "Finds points of interest for a landmark."

let landmark: Landmark
init(landmark: Landmark) {
self.landmark = landmark
}

@Generable
struct Arguments {
@Guide(description: "This is the type of business to look up for.")
let pointOfInterest: Category
}

let results = await getSuggestions(category: arguments.pointOfInterest,
landmark: landmark.name)
return """
There are these \(arguments.pointOfInterest) in \(landmark.name):
\(results.joined(separator: ", "))
"""
}
}

@Generable
enum Category: String, CaseIterable {
case hotel
case restaurant
}

switch category {
case .hotel : ["Hotel 1", "Hotel 2", "Hotel 3"]
case .restaurant : ["Restaurant 1", "Restaurant 2", "Restaurant 3"]
}
}

#### 5.2: Give the model access to the `FindPointsOfInterestTool` Heading self-link

Switch over to our playground and test the tool.

#Playground {
let landmark = ModelData.landmarks[0]
let pointOfInterestTool = FindPointsOfInterestTool(landmark: landmark)

let instructions = Instructions {
"Your job is to create an itinerary for the user."
"For each day, you must suggest one hotel and one restaurant."
"Always use the 'findPointsOfInterest' tool to find hotels and restaurant in \(landmark.name)"
}

let session = LanguageModelSession(
tools: [pointOfInterestTool],
instructions: instructions
)

let prompt = Prompt {
"Generate a 3-day itinerary to \(landmark.name)."
"Give it a fun title and description."
}

let response = try await session.respond(to: prompt,
generating: Itinerary.self,
options: GenerationOptions(sampling: .greedy))

let inspectSession = session
}

### App: Integrating the tool Heading self-link

You’ll introduce the `FindPointsOfInterestTool` tool to give `ItineraryGenerator` the ability to find points of interest.

#### 5.3: Updating the itinerary generator to use the tool Heading self-link

Open **`ViewModels/ItineraryGenerator.swift`**. You’ll modify the `init` method to create an instance of the tool and add it to the `LanguageModelSession`.

1. In the **`init`** method, create an instance of the `FindPointsOfInterestTool` tool and update the instructions to use it.

```swift
// MARK: - [CODE-ALONG] Chapter 5.3.1: Update the instructions to use the Tool
let pointOfInterestTool = FindPointsOfInterestTool(landmark: landmark)
let instructions = Instructions {
"Your job is to create an itinerary for the user."
"For each day, you must suggest one hotel and one restaurant."
"Always use the 'findPointsOfInterest' tool to find hotels and restaurant in \(landmark.name)"
}

2. Pass the tool to the `LanguageModelSession`.

```swift
// MARK: - [CODE-ALONG] Chapter 5.3.2: Update the LanguageModelSession with the tool
self.session = LanguageModelSession(
tools: [pointOfInterestTool],
instructions: instructions
)

3. Update `session.streamResponse` to include greedy sampling

```swift
// MARK: - [CODE-ALONG] Chapter 5.3.3: Update `session.streamResponse` to include greedy sampling
options: GenerationOptions(sampling: .greedy)

init(landmark: Landmark) {
self.landmark = landmark
let pointOfInterestTool = FindPointsOfInterestTool(landmark: landmark)
let instructions = Instructions {
"Your job is to create an itinerary for the user."
"For each day, you must suggest one hotel and one restaurant."
"Always use the 'findPointsOfInterest' tool to find hotels and restaurant in \(landmark.name)"
}

self.session = LanguageModelSession(tools: [pointOfInterestTool], instructions: instructions)
}

func generateItinerary(dayCount: Int = 3) async {
// MARK: - [CODE-ALONG] Chapter 6.2.1: Update to exclude schema from prompt
do {
let prompt = Prompt {
"Generate a \(dayCount)-day itinerary to \(landmark.name)."
"Give it a fun title and description."
"Here is an example of the desired format, but don't copy its content:"
Itinerary.exampleTripToJapan
}
let stream = session.streamResponse(to: prompt,
generating: Itinerary.self,
options: GenerationOptions(sampling: .greedy))
for try await partialResponse in stream {
self.itinerary = partialResponse.content
}

} catch {
self.error = error
}
}

**Build and Run the App (⌘+R):** The generated itinerary will now include the specific names of places returned by the tool, like “Restaurant 1” and “Hotel 2”.

## Chapter 6: Performance and optimization Heading self-link

This chapter explores key techniques to improve the performance of generative features: pre-warming the model and optimizing the prompt.

#### 6.1: Pre-warming the model Heading self-link

Pre-warming loads the model into memory _before_ it’s needed, reducing the latency of the first generation request.

1. **Add a `prewarm` function:** Open **`ViewModels/ItineraryGenerator.swift`** and add this new function to the class:

```swift
// MARK: - [CODE-ALONG] Chapter 6.1.1: Add a function to pre-warm the model
session.prewarm()

2. **Call `prewarm` when the view appears:** Open **`Views/2-LandmarkTripView.swift`** and add a call to our new function inside the `.task` modifier:

```swift
// MARK: - [CODE-ALONG] Chapter 6.1.2: Pre-warm the model when the view appears
generator.prewarmModel()

#### 6.2: Optimizing the prompt Heading self-link

When you provide a good few-shot example, the model often doesn’t need to see the full schema definition. You can remove it to save space and speed up processing.

1. Update the `streamResponse` call: Go
2. Modify the `session.streamResponse` call to add the `includeSchemaInPrompt: false` parameter:

```swift
// MARK: - [CODE-ALONG] Chapter 6.2.1: Update to exclude schema in prompt
includeSchemaInPrompt: false

init(landmark: Landmark) {
self.landmark = landmark

let pointOfInterestTool = FindPointsOfInterestTool(landmark: landmark)
let instructions = Instructions {
"Your job is to create an itinerary for the user."
"Each day needs an activity, hotel and restaurant."
"""
Always use the findPointsOfInterest tool to find businesses
and activities in \(landmark.name), especially hotels and restaurants.

The point of interest categories may include hotel and restaurant.
"""
landmark.description
}

self.session = LanguageModelSession(tools: [pointOfInterestTool],
instructions: instructions)

func generateItinerary(dayCount: Int = 3) async {
do {
let prompt = Prompt {
"Generate a \(dayCount)-day itinerary to \(landmark.name)."
"Here is an example of the desired format, but don't copy its content:"
Itinerary.exampleTripToJapan
}
let stream = session.streamResponse(to: prompt,
generating: Itinerary.self,
includeSchemaInPrompt: false)
for try await partialResponse in stream {
self.itinerary = partialResponse.content
}

func prewarmModel() {
session.prewarm()
}
}

}
.task {
let generator = ItineraryGenerator(landmark: landmark)
self.itineraryGenerator = generator
generator.prewarmModel()

**Build and Run the App (⌘+R):** These optimizations reduce the “time to first token” and make the generative feature feel more responsive, especially on the first run.

## Recap and next steps Heading self-link

Congratulations! You’ve completed the Foundation Models framework code-along. You’ve learned how to generate content, guide generation with structured types, build a responsive UI with streaming, extend the model’s capabilities with tools, and optimize performance.

Here’s a quick recap of the key concepts we covered:

- **Chapter 1: Foundation Models framework basics**: We started with the fundamentals of making a generation request, using instructions to guide the model’s output, and checking for model availability to ensure a smooth user experience.
- **Chapter 2: Generating structured outputs**: We moved beyond simple text generation to receiving structured data from the model. Using the `@Generable` macro, we defined custom Swift types that the model can populate, allowing for more predictable and type-safe results.
- **Chapter 3: Prompting techniques**: We explored advanced prompting techniques to improve the accuracy and reliability of the model’s output. We learned how to use the prompt builder to construct dynamic prompts and how to provide one-shot examples to guide the model.
- **Chapter 4: Streaming responses**: To enhance the user experience, we implemented streaming to display the model’s response as it’s being generated. This involved updating our `ViewModel` to handle partially generated content and modifying our views to render the streaming data.
- **Chapter 5: Tool calling**: We extended the model’s capabilities by creating a `Tool`. This allowed the model to call our Swift code to get information and perform actions, such as finding points of interest.
- **Chapter 6: Performance and optimization**: Finally, we optimized our app’s performance by pre-warming the model to reduce latency and by optimizing the prompt to save space and speed up processing.

We’re excited to see what you will build next!

---

