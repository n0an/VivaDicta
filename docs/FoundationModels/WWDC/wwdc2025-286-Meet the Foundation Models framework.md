# Meet the Foundation Models framework

Learn how to tap into the on-device large language model behind Apple Intelligence! This high-level overview covers everything from guided generation for generating Swift data structures and streaming for responsive experiences, to tool calling for integrating data sources and sessions for context management. This session has no prerequisites.

### Chapters

- 0:00 - [Introduction](https://developer.apple.com/videos/play/wwdc2025/286/?time=0)
- 2:05 - [The model](https://developer.apple.com/videos/play/wwdc2025/286/?time=125)
- 5:20 - [Guided generation](https://developer.apple.com/videos/play/wwdc2025/286/?time=320)
- 7:45 - [Snapshot streaming](https://developer.apple.com/videos/play/wwdc2025/286/?time=465)
- 11:28 - [Tool calling](https://developer.apple.com/videos/play/wwdc2025/286/?time=688)
- 16:11 - [Stateful session](https://developer.apple.com/videos/play/wwdc2025/286/?time=971)
- 21:02 - [Developer experience](https://developer.apple.com/videos/play/wwdc2025/286/?time=1262)

### Resources

- [Human Interface Guidelines: Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)
- [HD Video](https://devstreaming-cdn.apple.com/videos/wwdc/2025/286/4/6f221dca-f35f-4dad-bfec-0ec0970849bb/downloads/wwdc2025-286_hd.mp4?dl=1)
- [SD Video](https://devstreaming-cdn.apple.com/videos/wwdc/2025/286/4/6f221dca-f35f-4dad-bfec-0ec0970849bb/downloads/wwdc2025-286_sd.mp4?dl=1)

### Related Videos

#### WWDC25

- [Code-along: Bring on-device AI to your app using the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/259)
- [Deep dive into the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/301)
- [Discover machine learning & AI frameworks on Apple platforms](https://developer.apple.com/videos/play/wwdc2025/360)
- [Explore prompt design & safety for on-device foundation models](https://developer.apple.com/videos/play/wwdc2025/248)

## Transcript

Hi, I’m Erik. And I’m Yifei. And today, we are so excited to get the privilege of introducing you to the new Foundation Models framework! The Foundation Models framework gives you access to the on-device Large Language Model that powers Apple Intelligence, with a convenient and powerful Swift API. It is available on macOS, iOS, iPadOS, and visionOS! You can use it to enhance existing features in your apps, like providing personalized search suggestions. Or you can create completely new features, like generating an itinerary in a travel app, all on-device. You can even use it to create dialog on-the-fly for characters in a game.

It is optimized for generating content, summarizing text, analyzing user input and so much more.

All of this runs on-device, so all data going into and out of the model stays private. That also means it can run offline! And it’s built into the operating system, so it won’t increase your app size. It’s a huge year, so to help you get the most out of the FoundationModels framework, we’ve prepared a series of videos. In this first video, we’ll be giving you a high level overview of the framework in its entirety. Starting with the details of the model.

We will then introduce guided generation which allows you to get structured output in Swift, and the powerful streaming APIs that turn latency into delight.

We will also talk about tool calling, which allows the model to autonomously execute code you define in your app.

Finally, we will finish up with how we provide multi-turn support with stateful sessions, and how we seamlessly integrate the framework into the Apple developer ecosystem. The most important part of the framework, of course, is the model that powers it. And the best way to get started with prompting the model, is to jump into Xcode.

Testing out a variety of prompts to find what works best is an important part of building with large language models, and the new Playgrounds feature in Xcode is the best way to do that. With just a few lines of code, you can immediately start prompting the on-device model. Here I’ll ask it to generate a title for a trip to Japan, and the model’s output will appear in the canvas on the right. Now, I want to see if this prompt works well for other destinations too. In a #Playground, you can access types defined in your app, so I’ll create a for loop over the landmarks featured in mine. Now Xcode will show me the model’s response for all of the landmarks.

The on-device model we just used is a large language model with 3 billion parameters, each quantized to 2 bits. It is several orders of magnitude bigger than any other models that are part of the operating system.

But even so, it’s important to keep in mind that the on-device model is a device-scale model. It is optimized for use cases like summarization, extraction, classification, and many more. It’s not designed for world knowledge or advanced reasoning, which are tasks you might typically use server-scale LLMs for.

Device scale models require tasks to be broken down into smaller pieces. As you work with the model, you’ll develop an intuition for its strengths and weaknesses.

For certain common use cases, such as content tagging, we also provide specialized adapters that maximize the model’s capability in specific domains.

We will also continue to improve our models over time. Later in this video we’ll talk about how you can tell us how you use our models, which will help us to improve them in ways that matter to you.

Now that we’ve taken a look at the model, the first stop on our journey is Guided Generation. Guided Generation is what makes it possible to build features like the ones you just saw, and it is the beating heart of the FoundationModels framework. Let’s take a look at a common problem and talk about how Guided Generation solves it.

By default, language models produce unstructured, natural language as output. It’s easy for humans to read, but difficult to map onto views in your app.

A common solution is to prompt the model to produce something that’s easy to parse, like JSON or CSV.

However, that quickly turns into a game of whack-a-mole. You have to add increasingly specific instructions about what it it is and isn’t supposed to do… Often that doesn’t quite work… So you end up writing hacks to extract and patch the content. This isn’t reliable because the model is probabilistic and there is a non-zero chance of structural mistakes. Guided Generation offers a fundamental solution to this problem.

When you import FoundationModels, you get access to two new macros, @Generable and @Guide. Generable let’s you describe a type that you want the model to generate an instance of.

Additionally, Guides let you provide natural language descriptions of properties, and programmatically control the values that can be generated for those properties.

Once you’ve defined a Generable type, you can make the model respond to prompts by generating an instance of your type. This is really powerful.

Observe how our prompt no longer needs to specify the output format. The framework takes care of that for you.

The most important part, of course, is that we now get back a rich Swift object that we can easily map onto an engaging view.

Generable types can be constructed using primitives, like Strings, Integers, Doubles, Floats, and Decimals, and Booleans. Arrays are also generable. And Generable types can be composed as well. Generable even supports recursive types, which have powerful applications in domains like generative UIs.

The most important thing to understand about Guided Generation is that it fundamentally guarantees structural correctness using a technique called constrained decoding.

When using Guided Generation, your prompts can be simpler and focused on desired behavior instead of the format.

Additionally, Guided Generation tends to improve model accuracy. And, it allows us to perform optimizations that speed up inference at the same time. This is all made possible by carefully coordinated integration of Apple operating systems, developer tools, and the training of our foundation models. There is still a lot more to cover about guided generation, like how to create dynamic schemas at runtime, so please check out our deep dive video for more details. So that wraps up Guided Generation — we’ve seen how Swift’s powerful type system augments natural language prompts to enable reliable structured output. Our next topic is streaming, and it all builds on top of the @Generable macro you’re already familiar with.

If you’ve worked with large language models before, you may be aware that they generate text as short groups of characters called tokens.

Typically when streaming output, tokens are delivered in what’s called a delta, but the FoundationModels framework actually takes a different approach, and I want to show you why.

As deltas are produced, the responsibility for accumulating them usually falls on the developer.

You append each delta as they come in. And the response grows as you do.

But it gets tricky when the result has structure. If you want to show the greeting string after each delta, you have to parse it out of the accumulation, and that’s not trivial, especially for complicated structures. Delta streaming just isn’t the right formula when working with structured output.

And as you’ve learned, structured output is at the very core of the FoundationModels framework, which is why we’ve developed a different approach. Instead of raw deltas, we stream snapshots.

As the model produces deltas, the framework transforms them into snapshots. Snapshots represent partially generated responses. Their properties are all optional. And they get filled in as the model produces more of the response.

Snapshots are a robust and convenient representation for streaming structured output.

You’re already familiar with the @Generable macro, and as it turns out, it’s also where the definitions for partially generated types come from. If you expand the macro, you’ll discover it produces a type named \`PartiallyGenerated\`. It is effectively a mirror of the outer structure, except every property is optional.

The partially generated type comes into play when you call the \`streamResponse\` method on your session.

Stream response returns an async sequence. And the elements of that sequence are instances of a partially generated type. Each element in the sequence will contain an updated snapshot.

These snapshots work great with declarative frameworks like SwiftUI. First, create state holding a partially generated type.

Then, just iterate over a response stream, store its elements, and watch as your UI comes to life.

To wrap up, let’s review some best practices for streaming.

First, get creative with SwiftUI animations and transitions to hide latency. You have an opportunity turn a moment of waiting into one of delight. Second, you’ll need to think carefully about view identity in SwiftUI, especially when generating arrays. Finally, bear in mind that properties are generated in the order they are declared on your Swift struct. This matters both for animations and for the quality of the model’s output. For example, you may find that the model produces the best summaries when they’re the last property in the struct.

There is a lot to unpack here, so make sure to check out our video on integrating Foundation Models into your app for more details. So that wraps up streaming with Foundation Models. Next up, Yifei is going to teach you all about tool calling! Thanks Erik! Tool calling is another one of our key features. It lets the model execute code you define in your app. This feature is especially important for getting the most out of our model, since tool calling gives the model many additional capabilities. It allows the model to identify that a task may require additional information or actions and autonomously make decisions about what tool to use and when, when it’s difficult to decide programmatically.

The information you provide to the model can be world knowledge, recent events, or personal data. For example, in our travel app, it provides information about various locations from MapKit. This also gives the model the ability to cite sources of truth, which can suppress hallucinations and allow fact-checking the model output.

Finally, it allows the model to take actions, whether it’s in your app, on the system, or in the real world.

Integrating with various sources of information in your app is a winning strategy for building compelling experiences. Now that you know why tool calling is very useful, let’s take a look at how it works.

On the left we have a transcript which records everything that has happened so far. If you’ve provided tools to the session, the session will present these tools to the model along with the instructions. Next comes the prompt, where we tell the model which destination we want to visit.

Now, if the model deems that calling a tool can enhance the response, it will produce one or more tool calls. In this example, the model produces two tool calls — querying restaurants and hotels.

At this phase, the FoundationModels framework will automatically call the code you wrote for these tools. The framework then automatically inserts the tool outputs back into the transcript. Finally, the model will incorporate the tool output along with everything else in the transcript to furnish the final response.

Now that we have a high level understanding of tool calling, let’s define a tool.

Here we’re defining a simple weather tool, which conforms to the Tool protocol. The weather tool has kind of emerged as the de-facto ‘hello world’ of tool calling, and it’s a great way to get started.

The protocol first requires you to specify a name and a natural language description of the tool.

The framework will automatically provide them for the model to help it understand when to call your tool.

When the model calls your tool, it will run the call method you define.

The argument to the call method can be any Generable type.

The reason your arguments need to be generable is because tool calling is built on guided generation to ensure that the model will never produce invalid tool names or arguments.

After defining your arguments type, you can now write anything you want in the body of your method. Here we’re using CoreLocation and WeatherKit to find the temperature of a given city. The output is represented using the ToolOutput type, which can be created from GeneratedContent to represent structured data. Or from a string if your tool’s output is natural language. Now that we have defined a tool, we have to ensure that the model has access to it.

To do so, pass your tool into your session’s initializer. Tools must be attached at session initialization, and will be available to the model for the session’s lifetime.

After creating a session with tools, all you need to do is prompt the model as you would normally. Tool calls will happen transparently and autonomously, and the model will incorporate the tools’ outputs into its final response. The examples I’ve shown here demonstrate how to define type-safe tools at compile time, which is great for the vast majority of use cases. But tools can also be dynamic in every way! For example, you can define the arguments and behaviors of a tool at runtime by using dynamic generation schemas. If you are curious about that, feel free to check out our deep dive video to learn more.

That wraps up tool calling. We learned why tool calling is useful and how to implement tools to extend the model’s capabilities. Next, let’s talk about stateful sessions. You’ve seen the word session pop up in this video many times already. The Foundation Models framework is built around the notion of a stateful session. By default, when you create a session, you will be prompting the on-device general-purpose model. And you can provide custom instructions.

Instructions are an opportunity for you to tell the model its role and provide guidance on how the model should respond. For example, you can specify things like style and verbosity.

Note that providing custom instructions is optional, and reasonable default instructions will be used if you don’t specify any.

If you do choose to provide custom instructions, it is important to understand the difference between instructions and prompts. Instructions should come from you, the developer, while prompts can come from the user. This is because the model is trained to obey instructions over prompts. This helps protect against prompt injection attacks, but is by no means bullet proof.

As a general rule, instructions are mostly static, and it’s best not to interpolate untrusted user input into the instructions.

So this is a basic primer on how to best form your instructions and prompts. To discover even more best practices, check out our video on prompt design and safety.

Now that you have initialized a session, let’s talk about multi-turn interactions! When using the respond or streamResponse methods we talked about earlier. Each interaction with the model is retained as context in a transcript, so the model will be able to refer to and understand past multi-turn interactions within a single session. For example, here the model is able to understand when we say “do another one”, that we’re referring back to writing a haiku.

And the \`transcript\` property on the session object will allow you to inspect previous interactions or draw UI views to represent them.

One more important thing to know is that while the model is producing output, its \`isResponding\` property will become \`true\`. You may need to observe this property and make sure not to submit another prompt until the model finishes responding. Beyond the default model, we are also providing additional built-in specialized use cases that are backed by adapters.

If you find a built-in use case that fits your need, you can pass it to SystemLanguageModel’s initializer. To understand what built-in use cases are available and how to best utilize them, check out our documentation on the developer website. One specialized adapter I want to talk more about today is the content tagging adapter. The content tagging adapter provides first class support for tag generation, entity extraction, and topic detection. By default, the adapter is trained to output topic tags, and it integrates with guided generation out of the box. So you can simply define a struct with our Generable macro, and pass the user input to extract topics from it.

But there’s more! By providing it with custom instructions and a custom Generable output type, you can even use it to detect things like actions and emotions. Before you create a session, you should also check for availability, since the model can only run on Apple Intelligence-enabled devices in supported regions. To check if the model is currently available, you can access the availability property on the SystemLanguageModel.

Availability is a two case enum that’s either available or unavailable. If it’s unavailable, you also receive a reason so you can adjust your UI accordingly.

Lastly, you could encounter errors when you are calling into the model.

These errors might include guardrail violation, unsupported language, or context window exceeded. To provide the best user experience, you should handle them appropriately, and the deep-dive video will teach you more about them. That’s it for multi-turn stateful sessions! We learned how to create a session and use it, as well as how our model keeps track of your context. Now that you’ve seen all the cool features of the framework, let’s talk about developer tooling and experience. To start, you can go to any Swift file in your project and use the new playground macro to prompt the model.

Playgrounds are powerful because they let you quickly iterate on your prompts without having to rebuild and rerun your entire app.

In a playground, your code can access all the types in your project, such as the generable types that are already powering your UI.

Next, we know that when it comes to building app experiences powered by large language models, it is important to understand all the latency under the hood, because large language models take longer to run compared to traditional ML models. Understanding where latency goes can help you tweak the verbosity of your prompts, or determine when to call useful APIs such as prewarming.

And our new Instruments app profiling template is built exactly for that. You can profile the latency of a model request, observe areas of optimizations, and quantify improvements.

Now, as you develop your app, you may have feedback that can help us improve our models and our APIs.

We encourage you to provide your feedback through Feedback Assistant. We even provide an encodable feedback attachment data structure that you can attach as a file to your feedback.

Finally, if you are an ML practitioner with a highly specialized use case and a custom dataset, you can also train your custom adapters using our adapter training toolkit. But bear in mind, this comes with significant responsibilities because you need to retrain it as Apple improves the model over time. To learn more, you can visit the developer website. Now that you’ve learned many of the cool features provided by the new Foundation Models framework, we can’t wait to see all the amazing things you build with it! To discover even more about how you can integrate generative AI into your app, how technologies like guided generation work under the hood, and how you can create the best prompts, we have a whole series of wonderful videos and articles for you.

Thank you so much for joining us today! Happy generating!

## Code

2:28 - [Playground - Trip to Japan](https://developer.apple.com/videos/play/wwdc2025/286/?time=148)

```
import FoundationModels
import Playgrounds

#Playground {
    let session = LanguageModelSession()
    let response = try await session.respond(to: "What's a good name for a trip to Japan? Respond only with a title")
}
```


2:43 - [Playground - Loop over landmarks](https://developer.apple.com/videos/play/wwdc2025/286/?time=163)

```
import FoundationModels
import Playgrounds

#Playground {
    let session = LanguageModelSession()
    for landmark in ModelData.shared.landmarks {
        let response = try await session.respond(to: "What's a good name for a trip to \(landmark.name)? Respond only with a title")
    }
}
```


5:32 - [Creating a Generable struct](https://developer.apple.com/videos/play/wwdc2025/286/?time=332)

```
// Creating a Generable struct

@Generable
struct SearchSuggestions {
    @Guide(description: "A list of suggested search terms", .count(4))
    var searchTerms: [String]
}
```


5:51 - [Responding with a Generable type](https://developer.apple.com/videos/play/wwdc2025/286/?time=351)

```
// Responding with a Generable type

let prompt = """
    Generate a list of suggested search terms for an app about visiting famous landmarks.
    """

let response = try await session.respond(
    to: prompt,
    generating: SearchSuggestions.self
)

print(response.content)
```


6:18 - [Composing Generable types](https://developer.apple.com/videos/play/wwdc2025/286/?time=378)

```
// Composing Generable types

@Generable struct Itinerary {
    var destination: String
    var days: Int
    var budget: Float
    var rating: Double
    var requiresVisa: Bool
    var activities: [String]
    var emergencyContact: Person
    var relatedItineraries: [Itinerary]
}
```


9:20 - [PartiallyGenerated types](https://developer.apple.com/videos/play/wwdc2025/286/?time=560)

```
// PartiallyGenerated types

@Generable struct Itinerary {
    var name: String
    var days: [Day]
}
```


9:40 - [Streaming partial generations](https://developer.apple.com/videos/play/wwdc2025/286/?time=580)

```
// Streaming partial generations

let stream = session.streamResponse(
    to: "Craft a 3-day itinerary to Mt. Fuji.",
    generating: Itinerary.self
)

for try await partial in stream {
    print(partial)
}
```


10:05 - [Streaming itinerary view](https://developer.apple.com/videos/play/wwdc2025/286/?time=605)

```
struct ItineraryView: View {
    let session: LanguageModelSession
    let dayCount: Int
    let landmarkName: String
  
    @State
    private var itinerary: Itinerary.PartiallyGenerated?
  
    var body: some View {
        //...
        Button("Start") {
            Task {
                do {
                    let prompt = """
                        Generate a \(dayCount) itinerary \
                        to \(landmarkName).
                        """
                  
                    let stream = session.streamResponse(
                        to: prompt,
                        generating: Itinerary.self
                    )
                  
                    for try await partial in stream {
                        self.itinerary = partial
                    }
                } catch {
                    print(error)  
                }
            }
        }
    }
}
```


11:00 - [Property order matters](https://developer.apple.com/videos/play/wwdc2025/286/?time=660)

```
@Generable struct Itinerary {
  
  @Guide(description: "Plans for each day")
  var days: [DayPlan]
  
  @Guide(description: "A brief summary of plans")
  var summary: String
}
```

## Summary

- 0:00 - [Introduction](https://developer.apple.com/videos/play/wwdc2025/286/?time=0)
- The Foundation Models framework provides you with access to an on-device Large Language Model for macOS, iOS, iPadOS, and visionOS. The framework enables you to create personalized and innovative features such as search suggestions, itineraries, and in-game dialog, all while prioritizing user privacy as data remains on-device and can operate offline. The framework is optimized for content generation, text summarization, and user input analysis. To assist developers, Apple has prepared a series of videos that cover the framework's overview, guided generation, streaming APIs, tool calling, multi-turn support, and seamless integration into the Apple developer ecosystem.

- 2:05 - [The model](https://developer.apple.com/videos/play/wwdc2025/286/?time=125)
- Xcode's new Playgrounds feature is the optimal starting point to experiment with prompting the on-device large language model. With just a few lines of code, you can test prompts and see the model's responses in real-time. The on-device model, though impressive with 3 billion parameters, is optimized for specific tasks like summarization, extraction, and classification, and is not suitable for world knowledge or advanced reasoning. Break down tasks into smaller pieces to maximize its effectiveness. Guided Generation, a core component of the FoundationModels framework, addresses the challenge of integrating model output into apps. It enables you to build features more reliably by providing a structured approach to model generation, overcoming the limitations of relying on the model to produce easily parsable formats like JSON or CSV.

- 5:20 - [Guided generation](https://developer.apple.com/videos/play/wwdc2025/286/?time=320)
- With the import of FoundationModels, two new macros, '@Generable' and '@Guide', are introduced. '@Generable' enables the description of types for model-generated instances, which can be constructed from primitives, arrays, and composed or recursive types. '@Guide' provides natural language descriptions of properties and controls generated values, ensuring structural correctness through constrained decoding. This Guided Generation approach simplifies prompts, improves model accuracy, and speeds up inference. It allows you to receive rich Swift objects directly from the model, which can be easily mapped onto engaging views, all without needing to specify the output format in the prompt.

- 7:45 - [Snapshot streaming](https://developer.apple.com/videos/play/wwdc2025/286/?time=465)
- The FoundationModels framework differs from traditional token-based delta streaming for large language models. Instead, it streams snapshots — partially generated responses with optional properties — which are more robust and convenient for handling structured output. This approach leverages the '@Generable' macro, which produces a 'PartiallyGenerated' type mirroring the outer structure with optional properties. The 'streamResponse' method returns an async sequence of these partially generated types, enabling seamless integration with declarative frameworks like SwiftUI. Use SwiftUI animations and transitions to enhance user experience during streaming. Proper consideration of view identity and property declaration order is also crucial for optimal results.

- 11:28 - [Tool calling](https://developer.apple.com/videos/play/wwdc2025/286/?time=688)
- Tool calling enables an AI model to execute custom code within an app, enhancing its capabilities. This feature allows the model to autonomously decide when to use external tools to retrieve information or perform actions, such as querying restaurants, hotels, or weather data, based on the context of the person's request. The model can integrate with various sources of truth, like MapKit, to provide accurate and up-to-date information. This process involves the model generating tool calls, which are then automatically executed by the FoundationModels framework, and the results are inserted back into the conversation transcript for the model to use in formulating its final response.

- 16:11 - [Stateful session](https://developer.apple.com/videos/play/wwdc2025/286/?time=971)
- The Foundation Models framework enables stateful sessions with an on-device general-purpose model. You can provide custom instructions to guide the model's responses, specifying style and verbosity, though this is optional. You set your instructions, which are distinct from user prompts, and the model is trained to obey instructions over prompts to enhance security. Within a session, the model retains context across multi-turn interactions, allowing it to understand and refer to previous prompts and responses. The transcript property can be used to inspect these interactions. The framework also offers built-in specialized use cases, such as the content-tagging adapter, which supports tag generation, entity extraction, and topic detection. Customize these adapters for specific needs. Before creating a session, check the model's availability because it can only run on Apple Intelligence-enabled devices in supported regions. Proper error handling is also essential to manage potential issues like guardrail violations, unsupported languages, or exceeded context windows.

- 21:02 - [Developer experience](https://developer.apple.com/videos/play/wwdc2025/286/?time=1262)
- Playgrounds enable rapid iteration of prompts for large language models within an app project, allowing you to access all project types. The new Instruments app profiling template helps optimize latency by identifying areas for improvement in model requests and prompt verbosity. You are encouraged to provide feedback through Feedback Assistant