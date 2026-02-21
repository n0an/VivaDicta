# Code-along: Bring on-device AI to your app using the Foundation Models framework

Develop generative AI features for your SwiftUI apps using the Foundation Models framework. Get started by applying the basics of the framework to create an awesome feature. Watch step-by-step examples of how to complement the models with tools you build, stream results, and apply further optimizations for great performance.

### Chapters

- 0:00 - [Introduction](https://developer.apple.com/videos/play/wwdc2025/259/?time=0)
- 2:30 - [Prompt engineering](https://developer.apple.com/videos/play/wwdc2025/259/?time=150)
- 11:19 - [Tool calling](https://developer.apple.com/videos/play/wwdc2025/259/?time=679)
- 20:32 - [Streaming output](https://developer.apple.com/videos/play/wwdc2025/259/?time=1232)
- 24:32 - [Profiling](https://developer.apple.com/videos/play/wwdc2025/259/?time=1472)

### Resources

- [Adding intelligent app features with generative models](https://developer.apple.com/documentation/FoundationModels/adding-intelligent-app-features-with-generative-models)
- [Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [Human Interface Guidelines: Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)
- [HD Video](https://devstreaming-cdn.apple.com/videos/wwdc/2025/259/5/907f1051-5d00-46a2-bc67-53764270104f/downloads/wwdc2025-259_hd.mp4?dl=1)
- [SD Video](https://devstreaming-cdn.apple.com/videos/wwdc/2025/259/5/907f1051-5d00-46a2-bc67-53764270104f/downloads/wwdc2025-259_sd.mp4?dl=1)

### Related Videos

#### WWDC25

- [Deep dive into the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/301)
- [Discover machine learning & AI frameworks on Apple platforms](https://developer.apple.com/videos/play/wwdc2025/360)
- [Explore prompt design & safety for on-device foundation models](https://developer.apple.com/videos/play/wwdc2025/248)
- [Meet the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286)

## Transcript

Hi, I’m Naomy! Let’s dive into the world of SwiftUI and on-device intelligence. In this code-along, we’ll explore how to add exciting new features to your apps using the FoundationModels framework. I’ll take you through a step-by-step example as I create an app that’ll plan my next trip. The FoundationModels framework gives you direct access to Apple’s on-device large language model, and the possibilities of what you can create are truly endless! All of this runs on-device, so your users’ data can stay private. The model is offline, and it’s already embedded into the operating system. It won’t increase the size of your apps. With this framework, we can build features that are powerful, private and performant, on macOS, iPadOS, iOS, and visionOS. My friends and I want to go on a trip - but we need some inspiration of where to go and what to do. Planning can be hard, but using the FoundationModels framework is easy. Let’s use it to create an app that will do all the planning work for us! Here’s what we’ll build today. In my app, the landing page displays several featured landmarks, that we can browse through. Oh, those trees look interesting! Let’s select Joshua Tree. We can tap the Generate button, and that’s where the model will do the work for us! It will create an itinerary, and in the process, it will also use tool calling, to autonomously choose the best points of interest for our landmark. Ok, I think my friends will like this app, so let’s start building it! There are a few steps to using the framework that we’ll go over today. It all starts with prompt engineering. I’ll show you how to perfect your prompts using Xcode’s playground! We’ll use tool calling to complement the model, by letting it reach out to external sources to fetch points of interest for our landmarks. And we’ll stream output to start showing our itinerary as the model is generating it! To polish things off, we’ll profile our app and apply optimizations to get great performance with the FoundationModels framework. A great prompt is the key to getting great results. Prompting can often be a tedious task, requiring lots of iteration. I could run my app, examine the output, change my prompt, re-run and repeat this all over again, but then I’d be here all day, and I won’t actually have time for my trip! Luckily, Xcode’s updated Playground feature is here to help! To get started, ensure that the canvas is enabled.

This is like Previews for SwiftUI, but it will give us live feedback for any Swift code. Now, in any file in my project, I can import Playgrounds, and write a #Playground to iterate on my code.

Let’s start with the basics. I’ll import FoundationModels, create a session, and make a request.

In my prompt I’ll say: “Create an itinerary.” And just as I typed that, this automatically executed, and we can see the results in the canvas. I was a bit vague, wasn’t I? Let me start by adding a location.

Our prompt is much better. We got an itinerary this time. I’m satisfied for now, and I can always come back and tweak my prompt later on. We just discovered how easy it is to get started with the FoundationModels framework, by giving a prompt and receiving a string as output. But for my itinerary, I really want more structured output. I want to represent the result using my own data structures, but I don’t want to worry about parsing the model’s output. Guided generation enables the model to automatically create the data structures I want, as long as I annotate them as Generable. Let’s put this in practice. I have an Itinerary structure here that I’d like the model to generate. Let’s start by importing FoundationModels, and add the Generable annotation! The only requirement of Generable is that the types of your properties are also Generable. Luckily, common types like string are Generable out of the box. If you have nested types, like DayPlan here, then you can just make those Generable as well. Now that we have a fully Generable type hierarchy, we can proceed and the let the model generate Itinerary structures as our response. If you want greater control over the output, the Guide macro lets you put constraints on the values of your properties. You can add a guide with a description for example, like I'll do for the title here.

We can also constrain a property to a known subset of values.

I can add a count, to make sure my days array always has exactly three elements, and even use multiple guides for a property. I’ll go ahead and add a few more guides to my properties.

Guide descriptions are really another way of prompting the model. I highly recommend watching the “Deep Dive” video, where Louis will tell you all about Guided generation. And now that we have our prompt, and our Generable type, and we can put it all together.

Here’s our Itinerary Planner, where we’ll store all our Foundation Models logic. Let’s go ahead and create a session. And give it instructions. I can use the builder API here to create my instructions with ease. In this closure, I can pass in multiples strings, and even instances of my Generable type. Instructions are a higher level form of prompting. Here, I’ll define what the model’s job is.

We would like an itinerary, and I’ll give the model some information about the landmark selected.

Including an example is great, because it gives the model a better idea towards the type of response I’m looking for.

And I can pass in an instance of my Itinerary struct, which is defined below using a trip to Japan.

Because my Itinerary struct is Generable, Foundation Models will automatically convert it to text that the model can understand. Now, we’re ready to make our request, with our Generable type as output.

In our prompt, we’ll explicitly ask the model for an itinerary.

And to tie everything together - let’s set our itinerary to the response from the model.

Our final step is to display this in our UI. Let’s make our ItineraryPlanner Observable, so that out UI can know when our itinerary is generated.

And let's go ahead and add it as a state property to our LandmarkTripView, so that our view updates as the contents of the planner change.

If we initialize it here, it would be unnecessarily recreated even when the view doesn’t appear on screen, which has an undesirable performance cost. It’s better to defer the creation of the object using a task modifier. So let’s add a task and initialize our planner here.

This will only be called once when the view appears. When we receive an itinerary from the model, we can then display it.

I’m going to use another view here, called ItineraryView. In it, I’ll display my title, and then I’ll add some styling.

I’ll do the same for my description, and rationale.

I’ll go ahead and display my remaining itinerary properties in a similar manner using my other views. That’s a pretty good start, and the model will use the description we provided in the instructions to generate a basic itinerary. Let’s take it a step further. The framework offers a flexible tool protocol that enables the model to include external information in its responses. You can get super creative - from using people in your phone’s contacts, to events in your calendar, or even online content. The model autonomously decides when it makes sense to invoke your tools, and how often. To specialize my planner app ever further, I’ll create a tool that calls out to MapKit to fetch the best points of interest for a landmark. To create a tool, you’ll need to conform to the tool protocol. This includes a unique name to identify your tool, a natural language description of when to call the tool, and a call function - which is how the model invokes your tool, with arguments that you define yourself. Let’s start composing our tool. We’ll import FoundationModels, and MapKit.

I have a data structure that conforms to the tool protocol, with a name, and description.

The framework puts these strings in the instructions automatically, so that the model can understand what your tool does, and decide when to call it. A tool can also take input from the user, like the landmark that they selected.

We want our tool to fetch different kinds of points of interest, so let’s add an enum.

The model will use its world knowledge to decide which categories are most promising for a certain landmark. For example, it would be more likely to find a marina in the Great Barrier Reef than somewhere dry, and in a desert, like Joshua Tree. The model will generate this enum, so it needs to be Generable.

We’ll then define our Arguments struct, that uses our enum, together with a natural language query.

For the implementation, there’s the call method, which is how the model will invoke your tool when it decides to do so. I previously wrote some MapKit logic, that makes a request to MapKit, using the model generated natural language query as input, alongside the category selected by the model, and fetches points of interests within a 20km range of my landmark coordinates.

We’ll make a search with our requested constraints and return the results.

We can then implement the call method. Lets reach out to MapKit, filter our results, and return our output.

And that’s really all it takes to define a tool that fetches information from MapKit. To wire it up, let’s go back to our ItineraryPlanner.

And here’s the session that we created before. We’ll create an instance of our tool with the landmark that the user picked as input.

Then we can pass our tool into the session initializer.

This is enough to make the model call our tool, but we can even do additional prompting if we’d like it to be invoked more often. We can explicitly ask the model to use our tool and categories.

And there you go! We’re ready to test this out! In fact, if you don’t have a testing device at hand, that’s alright. If your development machine is running the latest macOS, and has Apple Intelligence enabled and ready, then we can conveniently run this in the iPhone and visionPro simulators. Let’s select Joshua tree, and ask for an itinerary.

Now, you may notice this is taking some time. This is because the model is returning us all the output at once - so we wait for each activity to be generated before receiving any results. Don’t worry - later on I’ll show you how to speed this up! And there we go, we received a fun itinerary! However, we actually forgot something pretty important. We just assumed the on-device Foundation Model is always available, but this isn’t always the case. The model’s availability depends on Apple Intelligence’s availability, and Apple Intelligence may not be supported, enabled, or ready on a given device! So, it’s important to check the status of the model, and handle that accordingly in our UI! Now, instead of having to test this with physical devices, or, the unthinkable - disabling AppleIntelligence just for testing purposes, we can use a nice scheme option in Xcode.

In our scheme, we can see the Foundation Models Availability override. Currently, it’s turned off. But any of these first three options are reasons why the models wouldn’t be on the device. So let’s go ahead and choose one, try to generate an itinerary, and see what happens in our app.

Oh, wow, that’s not good. We’re just showing an error here, and it’s not really actionable either. I need to go back and consider how I’ll integrate availability in my app. Let’s consider the three cases I showed earlier. If the device is not eligible to get Apple Intelligence, it doesn’t make sense to show the generate itinerary button. When selecting a landmark, let’s just let the user see a short description of it, using the the offline data we have in our app. In the second case, the device is capable, but simply hasn’t been opted into Apple Intelligence. We should let the user know this is why our itinerary planner is unavailable. They can decide if they’d like to opt in and access this feature. Finally, Model Not Ready just means that more time is needed for the model to finish downloading. We can simply tell the user to try again later, as our feature will soon be available. Now that we’ve designed our app behavior, we can take advantage of the availability API to determine what availability state our device is in! Here in my view, I’ll add a new variable for the model I’m using - in this case, the system language model. We can then switch on the availability state, if the model is available, we can just continue with the same behavior as before.

When Apple Intelligence is not enabled, let’s let the user know.

And if the model is not ready, we’ll tell them to try again later.

Otherwise - we’ll hide our itinerary button and simply display our fun fact.

I already have the Foundation Models override in my scheme set to Device Not Eligible. Let’s try this case again.

Ok - much better. Now, we just see a fun fact and the Generate Itinerary button has been removed to prevent the user from going down a path their device can’t support. If we look back now, our app waits for the entire itinerary to be generated, before showing it in the UI. Luckily, if we stream the itinerary as the model produces it, we can start reading recommendations right away! To use streaming, we’ll change the respond method that we call.

Instead of getting a full itinerary, we get a partial version. We can use the PartiallyGenerated data structure that’s automatically created for us. This is your Generable structure, but with all the properties made optional. So, I’ll go ahead and change the expected type of my itinerary.

Our result will now be a new async sequence with our PartiallyGenerated type as output.

Each element in our stream is an incrementally updated version of our itinerary. For example, the first element might have a title, but the other itinerary properties would be nil. And then the second element could have a title and description, and so on, until we received a fully generated itinerary. Now, I need to unwrap these properties in my views. Here it’s also good to think about which of your properties are ok to show without the others. In my case, itinerary has a title, then description, and then day plans, and this order makes sense. So, I’ll make my itinerary partially generated, and I'll unwrap my title, description, and rationale.

Now for my list of days: I also have to display my partially generated day plans. It’s great that PartiallyGenerable structures are automatically identifiable, so I don’t have to manage IDs myself. I can simply use Swift UI’s forEach with my partially generated structures.

It’s really that easy! Let’s add an animation based on our itinerary.

And some content transitions to our properties, so that our results stream smoothly into our views. I’ll go ahead and unwrap all the other properties, and now - we’re very close to the final product! Let’s test this out on my phone! Lets make the same request as before. And this time, we’ll immediately start to see the output streaming in our UI! As a user, I can go ahead and read the first day, as the content is being generated.

However, you may have noticed a bit of a delay before that first field appeared on screen. To fix this, it would really help to understand what’s going on behind the scenes. This is a great time to use the new Foundation Models Instrument, to get a deeper understanding of the factors influencing our performance. Let’s see what we can find by profiling our app! Earlier, we talked about running our app on the simulator. This is great for testing functionality - but it may not produce accurate performance results. For example, a simulator on an M4 Mac may yield faster results than an older iPhone. When looking at performance, it’s important to keep these differences in mind. I’ll be profiling on a physical iPhone. To get started, I have the Instruments app open on my Mac, and I’ll connect my phone.

We can go ahead and add the new Foundation Models instrument, and start recording, and then create an itinerary.

The Asset Loading track looks at the time taken to load the models. The default system language model, and the safety guardrail were loaded. The Inference track is also present in blue. Finally, the purple bar is the portion of time we spent tool calling. We can track the total time it took to generate the itinerary, as well as the input token count, which is proportionate to our instruction and prompt sizes. And this delay at the beginning was the portion of time it took to load in the system language model. There are a few ways we can make this faster. We just observed that part of that initial latency was captured in the Asset Loading track. The on-device language model is managed by the operating system, and it may not be held in memory if the system is serving other critical features, or if it’s been unused for some time. When I call session.respond, the operating system will load the model if it’s not already in memory. Prewarming can give your session a head start, by loading the model before you even make your request. It's best to do this when your app is relatively idle, and just after the user gives a strong hint that they'll use the session. A good example of when to prewarm is just after a user starts typing in a text field that will result in a prompt. In our app, when the user taps on a landmark, it’s pretty likely that they’ll make a request soon. We can prewarm before they press the Generate Itinerary button to proactively load the model. By the time they finish reading the description, our model will be ready to go! The second optimization can be added at request time. Remember the generating argument of the response functions? We used Itinerary here. Well, the framework automatically inserts the generation schemas of your data structures into your prompts. But this adds more tokens, increasing latency and context size. If the model already has a complete understanding of the response format before the request is made, then we can set IncludeSchemaInPrompt to false, and gain some performance improvements. When can we apply this optimization? The first case is if you’re making subsequent, same-type requests on a multi-turn conversation. The first request on the session already gave context for guided generation by including the schema in the prompt. So, we don’t need to do so for subsequent requests on that session. The second case is if your instructions include a full example of the schema. Remember how we passed in an example itinerary in our Instructions? In our case, this is sufficient - because our Itinerary structure has no optional properties. If you do have optional properties in your schema, then you’ll need to provide examples with all of the optional properties both populated, and nil. A final consideration - setting IncludeSchemaInPrompt to false means that we’ll lose the descriptions we added to our guides, although, if you’re using a thorough example, this shouldn’t be a problem. Let’s test these optimizations out! We’ll go ahead and set the IncludeSchemaInPrompt option to false in our request. We’ll also prewarm our session while the user is on the landmark description page. Let’s make a quick wrapper, and then invoke it on our session.

Now for the results! I went ahead and recorded this again and we can take a look at the results! The asset loading track already had some activity, before I tapped the Generate button! We can see a substantial reduction in input token count and the total response time is shorter now! Given the seconds we saved with these optimizations, we can rest assured we'll make our flight on time. And with that, I’m ready for my trip! Oh, but before I leave, here are some other sessions that may interest you. If you haven’t seen it yet, make sure to watch the "Meet" session to learn all about the framework. To go deep, there’s the "Deep dive" video and for more prompting best practices, check out "Prompt Design & Safety". Thanks for watching!

## Summary

- 0:00 - [Introduction](https://developer.apple.com/videos/play/wwdc2025/259/?time=0)
- Learn how to use Apple's FoundationModels framework to build an app that utilizes on-device intelligence to plan trips. The framework helps you create powerful, private, and performant features across macOS, iPadOS, iOS, and visionOS. The app generates itineraries for selected landmarks, autonomously choosing points of interest using tool calling. The process involves prompt engineering, utilizing Xcode's playground, streaming output, and profiling the app for optimal performance.

- 2:30 - [Prompt engineering](https://developer.apple.com/videos/play/wwdc2025/259/?time=150)
- Xcode's updated Playground feature streamlines the code-iteration process for Swift developers. It provides live feedback, similar to SwiftUI Previews, so you can write and test code in real-time. Using the FoundationModels framework, you can interact with a model through prompts. The Playground automatically executes the code as prompts are typed, enabling quick feedback on the output. To enhance the output structure, the Guided generation feature allows you to annotate data structures as 'Generable', enabling the model to automatically create and populate these structures. Further refine the model's output using the 'Guide' macro, which provides constraints and descriptions for properties. This allows for more control over the generated data, ensuring it meets specific requirements. The framework also offers a flexible tool protocol that enables the model to include external information in its responses. By leveraging these features, you can create an Itinerary Planner app that generates structured itineraries based on user inputs and preferences. The app's UI updates dynamically as the itinerary is generated, providing a seamless user experience.

- 11:19 - [Tool calling](https://developer.apple.com/videos/play/wwdc2025/259/?time=679)
- The example creates a specialized planner app that utilizes an on-device Foundation Model to enhance its functionality. To achieve this, the example defines custom tools that conform to a specific protocol. These tools have unique names, descriptions, and call functions. One tool fetches points of interest from MapKit based on a landmark selected by the person. The tool can take input from the person and generates an enum of different categories of points of interest, such as restaurants, museums, or marinas, using the model's world knowledge to determine the most promising categories for a specific landmark. You implement the call method for this tool, which interacts with MapKit, using a natural language query generated by the model and the selected category. The tool then filters and returns the relevant points of interest within a specified range. To integrate the tool into the planner app, create an instance of the tool with the user-selected landmark and pass it into the session initializer of the model. The model can then autonomously decide when to invoke the tool and how often. The example also demonstrates how to handle scenarios where the on-device Foundation Model is not available, such as when the device is not eligible for Apple Intelligence, the user has not opted in, or the model is not ready. The example implements appropriate UI updates and error messages to guide the user in these cases. The examples also explores the possibility of streaming the itinerary as the model produces it, allowing the person to start reading recommendations immediately rather than waiting for the entire itinerary to be generated.

- 20:32 - [Streaming output](https://developer.apple.com/videos/play/wwdc2025/259/?time=1232)
- The code uses a 'PartiallyGenerated' data structure — an optional version of the ‘Generable’ structure — to handle an incrementally updated itinerary. As new data arrives, the UI is updated with each partial version, showing available properties first (for example, title, then description, then day plans). Swift UI's 'forEach' displays the partially generated day plans. Animations and content transitions are added for smooth updates. Performance optimization is possible using the Foundation Models Instrument to reduce initial delay.

- 24:32 - [Profiling](https://developer.apple.com/videos/play/wwdc2025/259/?time=1472)
- To optimize the app's performance, the example conducts profiling on a physical iPhone using the Instruments app on a Mac. The Foundation Models instrument is added, and the time taken to load models and generate an itinerary is analyzed. Two main optimizations are: Prewarming the session. Loading the on-device language model before the user makes a request, such as when they tap on a landmark, reduces initial latency. Setting 'IncludeSchemaInPrompt' to 'false': This optimization avoids inserting generation schemas into prompts, decreasing token count and latency, especially for subsequent requests or when instructions include full examples of the schema. After implementing these optimizations, the example app shows a substantial reduction in input token count and total response time, significantly improving its efficiency.