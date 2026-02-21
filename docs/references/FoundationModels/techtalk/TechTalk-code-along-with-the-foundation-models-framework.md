Hello everyone and welcome to the Foundation Models Framework Code Along. My name is Shashank. I'm a technology evangelist here at Apple and today I'm excited to guide you through integrating on-device generative AI features directly into your app. We'll cover everything from basic prompting to generating structured output, streaming responses and more. we have an incredible team of experts in Slido. If you have any questions at any point, please ask there.

Let's start with a quick overview to get everyone on the same page. At WWDC24, we introduced Apple Intelligence, powered by large foundation models built into the core of our operating systems. This brought system level features like Writing Tools and Genmoji. Many of you have asked for access to the underlying models and at WWDC25, we delivered with the Foundation Models Framework. It gives you direct access to the same on-device large language model that powers Apple intelligence, all through a powerful Swift API. For developers, this on-device approach has major advantages. Because everything runs locally, user data remains private. Your features work entirely offline with no accounts to set up or API keys to manage. There's no cost to you or someone using the app for any of these requests. And since it's all part of the OS, there's no impact on your app size.

Today, we're gonna build an app together. We'll start with a simple static app that lists landmarks and transform it into a dynamic travel planner. You learn how to generate rich structure itineraries for a custom UI, stream the results in real time as they're created. You'll also learn how to give the model access to custom tools to find real points of interest. And finally, how to optimize your app for performance.

Let's do a quick tour of the final app you'll be building.

Here is a completed app running on my Mac. And this is what you'll have by the end of our session today. We'll start with a simple, clean list of famous landmarks built using SwiftUI. Let's pick a landmark. How about Serengeti? When we click into the detail view, you see a header image and description.

At the bottom is our generate itinerary button. When I click this, the app will call the on-device model to generate a complete three-day travel plan. Watch the screen closely as this happens.

The UI is building itself in real time. First the title, then the description, then the day-by-day plan. This is the streaming API we'll incorporate in chapter four, and it creates a fantastic dynamic user experience. And this here isn't just a block of code, it's rich structured response, which we learn about in chapter two. We have distinct sections for day with a title, subtitle, and a map. Notice the names here like Hotel 1 and Restaurant 1. These aren't random. Our app is using tool calling to get these names, which we'll cover in chapter five. The foundation model framework lets you create rich, structured, and intelligent experiences that feel seamlessly integrated into your app. This is what we're going to build together today. To get the most out of today's Code Along, you have three key resources. First is the Xcode startup project. It has all the boilerplate UI and assets ready to go. If you're watching on developer.apple.com or the developer app, You'll find this under resources on the bottom of the page. If you're watching this on YouTube, it's linked from the description.

Second is our step by step guide on the web page. This is your source of truth with all the instructions and code snippets. You can simply copy paste these to avoid typos. And finally, you have me on the live stream and team of experts behind the scenes to answer your questions. I'll be building this project right here with you, explaining the why behind each change.

Before we jump into the settings and set up the project, let's quickly go over the system requirements for today's session. Everyone is welcome to watch and follow along. However, if you plan on coding live with me, you'll need an Apple Silicon based Mac running macOS Tahoe and Xcode 26. You'll also need to make sure that Apple intelligence is turned on under settings. I'll be building and running the app directly on my Mac today, but you can also use Xcode 26 with a recent iPhone running iOS 26 as your target.

With that, let's move on to the prerequisite section in our Code Along Guide and get our startup project downloaded and configured.

Here in our guide, you'll see a prerequisite section.

First, please click the link to download the project file.

Here, once you've downloaded, you'll find a zip file that macOS may automatically unzip for you. Inside, you'll find a folder named Foundation Models Code Along. This is a startup project we'll be using today. It contains all the necessary views, models, and placeholder code to get us started. I have my project open here and ready to go.

The first thing we need to do is set the developer team. In the project navigator, select the project file.

Then select targets.

Click on signing and capabilities. And under team, select the dropdown and select your team.

To make sure everything is working correctly, select myMac as the run destination in the Xcode toolbar.

and then click on the Run button. This will build and run the project. Alternatively, you can use Command + R.

What I have here is the app that we're gonna be building and adding our generative AI features into. So this is our starting point and we'll be adding powerful features throughout this session. Now let's do a quick tour of our startup project.

First we have here our Playground.swift file under the playgrounds folder. This is where we'll iterate on our prompts and test out foundation models APIs in isolation without having to build and run our entire app. Once we're happy with a prompt here, we'll move this code into our app.

Next is our view models folder and the most important file for us here is itineraryGenerator.swift. All the core logic for creating and managing foundation model sessions, calling the framework APIs and processing the results will live right here. And finally, we have a views folder.

This is where all our SwiftUI code lives. For this code along, the UI is mostly pre-built to let us focus on the Foundation Models Framework. You'll notice that there are several files here and to make it easy to follow, the key files we'll be editing are numbered.

Our job will be to take the output of our itinerary generator and wire it up to these views to create the rich and interactive UI that you'll see in the app.

As you go through these files, you'll notice there are special comments formatted this way. Mark, Code Along, Chapter, and a number. Each number here corresponds directly to the chapter and section with the same number in your Code Along guide. You can use the Xcode Find Navigator to search for the chapter number to see all the outstanding code changes.

Enter the chapter number here, and you'll see all the code changes. As we complete each step, we'll keep deleting these comments so we can track progress throughout the Code Along.

So in summary, we'll follow three simple steps. First, experiment in the playground. Second, implement the core logic in the view model, and finally, display the results in the view. Let's take a closer look at each of these views.

The first screen is a starting point, the main list of landmarks. This is powered by LandmarksView.swift. We won't be touching this file today. It's all set up for us to let us browse and select a destination. When you tap a landmark, you land on the details screen. This view is controlled by the landmark DetailView.swift file. Its main job is to check if the Foundation Models Framework is available on device and decide what UI to show based on that.

Next is the landmark trip view. Its role is to present the generate itinerary button. And this is also where we'll first display the raw unstructured text that we get back from the model.

And finally, the itinerary view is our destination. This view renders the rich structured itinerary data we'll have towards the end of the code along.

We're now ready to dive into the agenda. We've structured the code along into six chapters. We'll start with the absolute basics where you learn how to start prompting the model to generate text. Then we'll move beyond simple text and see how to get structured Swift types back from the model, making it easy to map model output to your custom views. We'll then dive into prompting techniques. That lets you improve models accuracy by providing high quality examples directly in your prompts. Next, we'll learn how to stream the model's response to update the UI in real time for a great user experience. We'll then explore tool calling. Tools are powerful ways to give the model access to your own custom functions and data to extend its capabilities.

And finally, we'll cover performance optimizations to make our generative features feel faster and more responsive. With that, let's dive into the basics of Foundation Models Framework. You can use the Foundation Models Framework to send a prompt to the on-device large language model, or LLM for short. The LLM can then reason about your prompt and generate text. For example, you could ask it to generate a three-day itinerary to Paris, and the model will respond with a detailed plan.

To start prompting the model, you'll need to create a session. The framework is built around this idea of stateful language model session, which maintains a history of all prompts and responses.

In this chapter, we'll get familiar with foundation models prompts and sessions. First, we'll start in the playground to get a feel for the API. We'll create a language model session and get our first response from the model. Then, we'll add concise instructions to shape the tone and content. Next, we look at availability API to handle different states gracefully. Once we are comfortable, we'll switch to the app, update the itinerary generator in a view model, and display the raw text output in our views. So let's head on over to our Code Along Guide.

Our goal in chapter one is to make our very first request on-device language model. We'll use the Xcode Playground to send a simple text prompt and see what happens. This will help us understand the model's basic behavior.

Feel free to copy and paste this code block into Xcode Playground.swift file and you can use this handy copy button on the top right corner. I'll be adding these lines of code step by step and explaining what is going on. Let's head over to our Xcode. open up our Playground.swift file. To prompt a model, you need three simple steps. The first is to import the Foundation Models Framework, which we've already done. The next step is to create a playground.

As soon as you use a playground macro to create a playground, you'll see a canvas show up on the right. If it doesn't, you can always click on editor options and ensure that there's a check mark next to canvas. you can click the refresh button and what that does is run all the code contained within the playground block. Right now you don't see an output because we haven't added anything. Step two in prompting the model is to create a session.

What we have here is let a variable session equal to language model session and you'll see the playground canvas automatically shows what is in the session variable. So you see that there are tools which we'll discuss in a later chapter and then transcript which includes all the conversations that you have with the model.

Step three is to prompt the model.

We say let response equal to try await session dot respond to and provide a prompt generate a three day itinerary to Paris. This is an async request so we await its response.

As soon as we do that, on the right side on the canvas, you'll see we have a response variable which includes a few properties. First is prompt. The prompt shows generate a 3-day itinerary to Paris and then there's a property called content which is of type String.

Let's click on this and you'll see that there's a detailed 3-day itinerary to Paris. Certainly here's a 3-day itinerary for exploring Paris, highlighting some of the city's most iconic sites and experience, and you see day by day plans for day one, morning, afternoon, and so on.

Great. Let's go back to our guide here and discuss a key topic. When you make the very first call to Session.response, you might notice that there's a slight delay. This is because the on-device language model needs to be loaded into memory before it can process your request. Our first request triggers a system to load the model, which causes the initial latency. We'll see how to address this in a later chapter. And we also saw that the output was unstructured natural language text, which is easy for us to read, but hard to use in a custom Swift UI. In the next chapter, we'll see how to generate structured output using Swift types instead of raw text. Finally, it's important to note that the entire itinerary without any data ever leaving your device. It's completely private and works offline. So congratulations, you've successfully prompted the on-device foundation model using the Foundation Models Framework.

Oh, and one last thing, let me head back to our playground.

We are always interested in improving the model, and if you want to provide feedback, you can always use these buttons right here in Canvas to share your feedback with us. Let's head on over to our Code Along Guide to Section 1.2, Guiding the model with instructions.

Our goal now is to get more consistent and higher quality results. We can do this by providing the model with instructions. Think of instructions as permanent rules or persona for the entire conversation within a single session. Feel free again to copy this piece of code into Playground and run it. and I'm going to go and add these instructions.

Back in our Playground.swift file, I add a new variable called instructions, and I say, your job is to create an itinerary for the user. Each day needs an activity, hotel, and restaurant. Always include a title, a short description, and a day-by-day plan. We can pass these instructions into the language model session using the instruction argument. When you pass this, the canvas will automatically detect code changes and update our results. We see now that we have our content property under response and this will include the request that we made, which is include activity, hotel and restaurant, and you can see this here, activity, hotel, and restaurants.

A question you may have is, what is the difference between these instructions and prompts? Let's take a look.

Instructions can be used to define a persona, set rules, and specify desired format for the response. This should come from the developer. Prompts, on the other hand, can come from someone using the app. The model is trained to obey instructions over prompts, and this can help protect against prompt injection attacks where the user may ask the model to ignore guidance provided in the prompt. As a rule, keep the instructions static and avoid inserting user input into them.

Also note that instructions are maintained throughout the session's life. Every interaction is recorded in the session's transcript, and The initial instructions are always the first entry.

Great, we're able to successfully prompt a model and get responses. But it's important to consider that our app might run on devices where Apple intelligence isn't available and showing a non-functional feature can be a bad user experience.

For example, the device may not even support Apple intelligence or The device may support Apple intelligence, but the user has not enabled it. Or the model assets are still downloading and they're not ready for use yet. Let's take a close look at how to handle these cases. We'll head on back to our Code Along Guide. We are now in section 1.3 in our Code Along Guide, Handling Model Availability.

The model provides APIs for availability.

Let's head on over to Xcode and take a closer look at each of these cases in this switch block and what they mean for your app.

Back in our Playground.swift file, a neat feature of playground is you can add multiple of these in the same Swift file.

I added a new # playground block here that includes the availability code. All right. Let's take a look at these APIs. You can also check the output of the multiple playgrounds. The second playground will show up as a second tab here on our canvas. And you'll see my Mac does support Apple intelligence. So it says foundation model is available and ready to go. Let's take a closer look at these cases now.

The first case is available. This means you have a green light. the model is loaded and you're ready to make generation requests.

If it says unavailable and device not eligible, this means the model doesn't support Apple Intelligence. You should gracefully hide the generative UI and show an alternate experience.

For unavailable and Apple Intelligence not enabled, this means the device is capable, but Apple Intelligence is turned off in settings. This is your chance to prompt the user to enable it.

Unavailable and model not ready, this is a temporary state, likely because the model assets are still downloading. The best practice is to tell the user to try again. We're now ready to add these features into our app. Let's head on over to our Code Along Guide.

We're now in the app section of chapter one. In this section, we'll update our landmark DetailView.swift to check the model availability and display a message if it is unavailable.

Feel free to copy these code blocks. You can search for these marked comments to know exactly where to insert these code changes and I'll be doing this live with you. Let's head on over to our Xcode project and click on landmark detail view.swift in the views folder. Again, as a reminder, you can always use the find navigator to look for all the code changes that you need to make in this chapter. All right, the first thing to do is to add our model instance.

So we say private let model equal to system language model.default. This is exactly the same line of code we used in our playground, so it should look familiar to you. And since I've added this, I'm gonna delete this comment. So it disappears from our find navigator. The next code change we need to do is to delete this placeholder availability code I have here. This was purely for convenience, so I'm gonna delete this. And as soon as I do that, Xcode will promptly remind me that availability has not been defined yet, but that's an easy fix because we have our model now, model.availability.

And I'm gonna get rid of this line of code too. Okay? With that code change, we've made all the changes to this specific file. Now, we've added these availability checks, which is familiar to you because we use the same in the playground, but how do you test them? You may not have access to multiple test devices. Thankfully, there's an easy way. Right here in the scheme settings in the project, there's an option to simulate unavailability. Let's take a look. Click on foundation models code along, click edit scheme, and if you scroll down, you'll see an option that says simulated foundation models availability.

If you click this, there are a few different options, and these options should be familiar to you because these are the cases we covered in the playground. So I'm gonna click Apple Intelligence Not Enabled, close, and I'm going to build and run our app.

We have our app here, I'm gonna select Sahara Desert, and aha, I see a message here that says, Trip Planner is unavailable because Apple Intelligence has not been turned on.

And this is the same message we have in our unavailability view.

Great. Let me switch this back so we can keep adding additional features throughout the code along.

All right. Let's head on over to section 1.5 in our Code Along Guide.

Now we are ready to update the app's itinerary generator to initialize a language model session and define a function called generate itinerary to invoke the model from our views. The code again should look familiar to you because we already implemented this in the code along. Now we'll be migrating this into our app. So let's head on over to Xcode and open our itinerary Generator.swift file, which you will find in the view models folder.

We'll again use our find navigator to look for all the code changes that we need to make and track progress. All right. In itinerary Generator.swift file, the first change we'll need to make is to add a session property.

And I'm going to do that first. So we define a variable called session for language model session.

Next, Xcode will remind us that we have not initialized a session. So we are going to initialize this session right here in the init functions.

Okay, so here's what we added. We added an instructions variable where we use the same instructions we had in the playground. Your job is to create an itinerary for the user. Each day needs an activity hotel and restaurant. Always include a title, a short description, and a day-by-day plan and I have a session with language model session and we pass in the instructions.

Okay, the third and final change we need to do is to update our generate itinerary function. This is the function that we'll invoke from our views in order to send in the prompt and get back a response. Let's go make this code change.

Okay, here's what we added. First, we said let prompt equal to generate a day count day itinerary to landmark.name. Day count here defaults to three and then landmark.name is the name of the landmark that the user clicks on when they open the app. So we gather this name and we pass it to the prompt So we can generate a response for that specific landmark. Next, we have letResponse equal to tryAwaitSession.Response and pass in a prompt. Finally, the response variable has a property.content, which you can recall from our playground canvas that we observed, which had all the natural unstructured text, which is a string, and we assign it to itinerary content.

That includes all the code changes for our view model, which is now ready to be called from our views. Let's head on back to our Code Along Guide to section 1.6. This is our final section in chapter one. We will now update the landmark trip view to take the output from the itinerary generator and display it in the app. Again, feel free to make these code changes by following along these comments. I'm gonna head over to Xcode.

Click on Views.

And landmark trip view. Okay.

All right, the first code change we'll need to make is to add a local variable for the itinerary generator class in our view model.

All right, so we have itinerary generator of the type itinerary and I'm gonna delete this comment.

The next code we need to do, a code change we need to do is to create an instance of this when the view is loaded.

So here's what we introduce under task modify. We said let generator equal to itinerary generator, which is the ViewModel class, and we pass in the landmark, so that it has information about which landmark the user clicked on, which if you recall, we pass it to the prompt. And then we hold on to the itinerary generator here. I'm going to delete the code change that we just made.

The next change we need to do is to update our view itself. Let's take a closer look at the view. By default, we have a Boolean variable here called requested itinerary. It is set to false.

Because it's set to false, we load up the first view on top here, which is a text field that has the landmark name. We access the landmark.name, and then we access the short description using Landmark.shortDescription. This is what shows up when the user has not generated, asked the model to generate an itinerary. But when the requested itinerary is set to false, we need to load up a new view where we can populate it with the model's output, and that is what we are going to implement right now. So I'm gonna remove the else case here and introduce a new else case where I say, if let content equal to itinerary generator dot itinerary content. If you recall, itinerary content is the string variable has our model's output. And then we simply take that content and we update it in our text view. Since we made this change, I'm gonna get rid of this comment too. We're almost there. We have one final change in this view. If you scroll back down here, we've defined a button that will show up at the bottom of the screen and currently this button is hidden. So we'll need to make two minor code changes here. One, we want to show the button so you can either comment this out or straight out delete it like what I'm doing. And then we need to insert code here to generate the itinerary when the user taps on the button. So let's add that here. Okay, so we said await itinerary generator and we invoke the generate itinerary function. If you recall, this is the function that takes the prompt and then passes it to the model and gets the output. That concludes all the code changes in this chapter.

Okay, we are now ready to build and run this app. Click on the run button here, which will build and run the app.

Here is our app. I'm gonna click on Sahara Desert here and we see that we have our generate itinerary button and when I click on this generate itinerary button, the prompt and instructions are being sent to the on device LLM which is going to generate a response asynchronously, token by token, right here on device.

If you see this itinerary like I do, congratulations, you built your very first fully functional on-device generative AI feature using Foundation Models Framework. With just a few lines of Swift, you've tapped into the power of Apple Intelligence.

This is great, but what we have here is a wall of text. What if I wanted to pull out a hotel name and show it on a map? This isn't the rich experience that we want. We'll address this in chapter two with guided generation. We'll discuss how you can get outputs using Swift structs directly from the model. For now, let's quickly recap chapter one.

In this chapter, we learned how to create a session and prompt the model for a basic text response. We saw how to provide instructions to guide the model's output and we covered how to handle different availability states using the availability API. Finally, we integrated these features into our app by updating the view model and view.

That wraps up chapter one.

Now that we can generate raw text, let's see how we can get structured data from the model to build a much richer UI.

Let's start with a fundamental challenge when working with LLMs. By default, they give us unstructured text, like the itinerary we just generated. While a human can read it, for an app developer, this can be challenging to work with. For example, how would you reliably extract the hotel for day one to plot it on a map? You'd have to write complex string parsing code that could break if the model's output changed. What we want instead is structured data that maps directly to our apps logic.

We'd need a more advanced nested structure that can be implemented using Swift structs. This itinerary object should contain an array of objects which in turn should contain an array of activity objects and so on. This is where guided generation comes in. The Foundation Models Framework provides APIs that allow you to specify exactly what your output should look like. If you have a Swift struct, you can simply apply @Generable to it. And this lets the model generate structured data using native Swift types.

We'll start this chapter in the playground where we'll define a simple struct with a generable macro applied to it. We'll then build on it to create more complex nested data structures for the model to generate. Finally, we'll go back to the app, we'll refactor our itinerary generator to output our new structured itinerary type and update our views to display it in a rich UI.

Let's head on back to our Code Along Guide.

We're now in chapter two, generating structured outputs. Our goal is to move beyond simple strings and get structured type-safe Swift data directly from the model. This will allow us to build rich custom UI without any fragile string parsing.

Feel free to copy this piece of code again into Playground and take a look at its output. And I'll be explaining what is going on when we introduce this new struct called simple itinerary. Let's go to the Xcode Playground file and make these code changes.

I'm gonna get rid of the second playground we just added and right here I'm going to introduce this new struct called simple itinerary. Let me walk through what this looks like and how we can incorporate it in our foundation model code to generate this output. First, this struct has a few different properties. It has a title, which is of type String. It has a description, which is of type String. And it has days, which is an array of String.

We want the model to generate these fields and we can provide it additional information by providing guides. The guide has a description argument which says, an exciting name for the trip. This tells the model that it has to generate a title for this variable and similarly we have description, a short and engaging description for the trip and similarly for day count. What we can do now is provide this to the model and we can do that using the generating argument. So previously we had Session.response and just the prompt. So I'm going to add a new argument called generating and provide simple Itinerary.self.

And we can go and refresh our canvas.

This will run through the code and we'll take a look at the output.

Okay. We have our response here. And let's take a closer look at the content property here.

Previously, this content was a string. If you look carefully here, it says this is a struct simple itinerary. Let's open this up. And what you'll notice is the output one to one matches with the struct that we just defined here. So we have our title, which is Parisian Bliss. And that is our title property here. We have our description that is right here. And then we have our array of String. So you'll see days, which is an array of String with day by day activity plan.

Awesome. So let's go back to our Code Along Guide and the section 2.2. An itinerary doesn't just have to be string or array of Strings. It can have nested structs too. Now, let's take a look at a full itinerary struct that we'll be building in our app. So we're going to make a small code change here. All you have to do is replace simple itinerary with itinerary.self, and we are going to make this code chain and I'll explain what this itinerary struct looks like. Back to Xcode.

I'm going to delete this simple itinerary and replace simple itinerary with just itinerary. Okay, so what does itinerary look like? You can command and click on this to open the definition or head on over to the models folder, click on itinerary.swift file, and here you'll see a new struct called itinerary which has similar fields to what we saw in simple itinerary but more. Let's take a closer look. It also has a title which is of type String. It has a description, it has rationale. And if you take a closer look at days, you'll see that it's no longer an array of String. It is actually an array of day plan, which in turn is its own struct. It has its own title, its own subtitle, its own destination and an activity, which is an array of another struct called activity, which has a type, title, description, and type here happens to be an enum, which is also generable. The enum is a great way to have the model generate specific cases that are predefined. For example, here, the type can only be sightseeing, food and dining, shopping, hotel and lodging. If you scroll all the way up to the top, there is another way to constrain what the model can generate. We can use enums or here for destination name. We have a guide that says any of and we provide model data dot landmark. What this tells the model is that it has to generate a destination name that is one of the landmarks that we see when we open up the app. This includes the Serengeti, the Grand Canyon, Sahara Desert and so on. So the output must be one of these. So this is what the itinerary struct looks like. And this is what we actually use in the app. Let's head on back to our Swift playground. And because if you recall, we said the destination name should be one of the names from the list. Paris is not part of the list. So I'm going to change it to something that is actually on the list. How about Grand Canyon? Canvas will detect this code change and let's take a look at the output.

There we have our response. It includes a content and again, if you take a closer look, it is of struct itinerary, not simple itinerary because we updated it. Let's open this up. You'll see it has a title, destination name, description, rationale and days, which is an array of date plan struct. You open it up, you have multiple days, and activities is a type of an activity struct, and so on.

The key thing to note here is that when you apply @Generable, it is completely composable. The framework understands how to build this entire complex object from the top down, all while guaranteeing structural correctness. Now let's integrate this into our app. Let's head on over to our Code Along Guide. We're now in the app section of chapter two. In this section, we'll update our itinerary generator to use the itinerary generable struct that we just tested in the playground. Feel free to copy this code again and I'm going to be making these code changes with you. So let's head on over to itinerary generator under view models folder and bring up my find navigator, set it to chapter 2 so I can take a look at all the code changes I'll be making in this chapter. The first code change we need to make is way up top here where we have to update our itinerary content to not be a string anymore but be a type of type itinerary. So let's first change the name of this variable to just itinerary and update string to itinerary. We can delete this comment because we've made this code change. The next code change we need to do is if you scroll down to the generate itinerary function you see that Xcode is promptly reminding us that itinerary content no longer exists. So we can update this to itinerary because we just added this. And it is complaining because the content currently that is coming out of Session.respond is a string. So similar to last time in the playground, we're going to add the generating argument and provide itinerary.self.

So the model can now output a value that is of the type itinerary and because we made this code change I'm going to get rid of this comment right here. Okay, the final change we'll need to make is to remove additional structural guidance that we are providing in our instructions. Notice how we say each day needs an activity, hotel and restaurant, always include a title, short description, day by day. But all of this information is already in our itinerary generable struct. We don't need to provide it again in our instructions. So the benefit, another benefit of using generables is you can make your prompts much simpler, which can help improve performance as well. So I'm gonna get rid of this comment.

And that concludes all the code changes in this section. So we've updated our itinerary generator view model to be able to generate our generable structure. Let's head on over to section 2.4, updating our view to display the structure data. In this section, we'll update our landmark trip view to generate itinerary view instead of the raw text that we saw in the previous section. This is a very quick code change, so let's head on over to our landmark trip view, which you'll find as the second number to find the views folder.

And the code change we'll need to make is right here.

If you recall previously, we loaded this view when the model output was generated, but we are no longer generating a string. So we can no longer use a text view. So first we have to update this, but then we also need to update this with another view instead of text so that we can actually extract the fields from our itinerary and populate it in a rich UI. So let me replace this with an updated view and I'll talk about what that looks like.

Okay, so here is what I did. And you can also copy and paste this from our guide. Let's take a closer look. So I said itinerary equal to itinerary generator.itinerary. And instead of the text view, we have this itinerary view, which takes in a landmark and takes in the generated itinerary. Now this itinerary view exists in our views folder but we haven't looked at it so let's take a closer look. This should be the file number three of course you can also command and click on this to open it up. Alright we won't be making any code changes to this file in this chapter but you see comments here which means we'll likely be making changes will surely be making changes in a later chapter. What this view does is it can take an itinerary that was generated by the model, extract the fields and create the rich UI we saw in the initial demo. If you take a closer look at our body here we see it can extract the itinerary title, its description, populated and then it's if you scroll down you'll see that when it extracts the day-by-day activity, there is a dedicated view called day view that can show that and we use for each to loop through these and extract all the properties and lay it out. Notice this is so much simpler than being able to parse strings and update it.

All right, so let's head on over to our slides. So the key benefit of guided generation is that it fundamentally guarantees structural correctness. It uses a technique called constraint decoding to do that. What it does is give you control over what the model should generate, whether that be strings or numbers or arrays or even a custom data structure that you define.

This also means that our prompts can be a lot simpler and more focused on the desired behavior instead of prompting the model for specific output formats. This also tends to improve model accuracy allow for optimizations that speed up inference. So to recap, in this chapter we explored how to get structured data from the model. We use the generable macro to define our own Swift types and saw how to create complex data structures by nesting them. We then updated our app to generate and render this structured data in a rich user interface. Let's go build this model to take a look at all the changes we did. Here's our app. Let's click on Sahara Desert and generate itinerary. Similar to before, it's going to take our prompts and instructions and send it to the model and now instead of generating the wall of text, it generates the itinerary type, we extract all the fields, and then populate it in our app using the new view, which is itinerary view. All right, this concludes this chapter. And then, now we are getting that we're getting structured data as model outputs. We can now switch gears and focus on improving the quality and consistency of the output with additional prompting techniques.

While a good prompt tells the model what to do, sometimes it's more effective to just show it. We can include a high quality example as an instance of our generable type directly in a prompt.

This is great because it gives the model a better idea towards the type of responses I'm looking for. So in this chapter, we'll be focusing on improving the quality of our generated content. We'll start again in the playground by using the Prompt Builder API to create more dynamic prompts. Then we'll explore one-shot prompting by providing a high quality example in the prompt to improve the model's accuracy. Finally, we'll integrate what we learned into our apps itinerary generator.

Let's head on over to our Code Along Guide.

We're now in chapter three, prompting techniques. Our goal now is to improve the quality and reliability of a model's output. First, we'll explore how to introduce dynamic prompts using the Prompt Builder API.

Let's head on over to Playground and take a look. Again, feel free to copy this code block into your Playground.swift file.

We are in Xcode, Heading over to Playground.swift file.

Okay. The key code change we're gonna make here is to introduce a prompt using the prompt builder API. Previously, if you recall, under Session.respond, we provided the two argument with generate a three-day itinerary to Grand Canyon in the format of a string. But instead, we can define the prompt not as a string, but using the prompt builder API and passing the values to a closure. The key benefit is that it can now include things like Swift conditionals. So right up top here, we have a variable called which is a Boolean, which is currently set to true. And then within the Prompt Builder API, I use this Boolean to conditionally update my prompt. So if the kit-friendly Boolean is true, then we inject this additional information into the prompt, which is the itinerary must be kit-friendly. We can update our Session.response call to include this new prompt and refresh our canvas.

Let's take a look at our output.

We have our response variable, content.

I'm gonna open up rationale here and take a look. So it says, this itinerary provides a safe, engaging and educational experience for children, ensuring they enjoy the natural beauty of Grand Canyon while being supported by age appropriate activities and accommodation. So you'll see that the model is honoring our request and this came in as a conditional and the benefit of this again is that you can have these prompt speed dynamic. This could be something that the user selects on the app or it could be something that you learn as a developer from the user's preference and update a prompt.

Awesome. Let's go back to our Code Along Guide to section 3.2. Our goal now is to use a more advanced prompting technique called one-shot prompting to show the model exactly what a high quality response looks like. So let's head on over to our Code Along.

So right in my prompt filter API here inside disclosure, I'm going to add another line of code here. Here I say, here is an example of the desired format, but don't copy its content. And I introduce an example. Let's take a closer look. It says Itinerary.exampleTripToJapan. Now what is this? So you can command click on this or head over to models folder, click on itinerary and scroll down and you'll see that example trip to Japan is defined right here. The first thing that you'll notice that this is not a big string that includes an example. This is actually an instance of the itinerary generable with all its properties populated. You'll see that we have a title, a destination name, description, rationale, days, and all the properties manually populated for you. We can head back to our playground and you'll see that we do have an output here and this output will include the additional information that we provided as a one-shot example in order to guide the tone and quality of the response.

The most important part is that we are embedding this itinerary.exampleTripToJapan directly into the prompt. This is our golden example. We're also telling the model explicitly, don't copy its content. We wanted to learn from the style and structure and not just repeat the data. Let's head back now to our guide.

We're now in the app section of chapter 3. We'll now integrate this one-shot prompting approach into the app. The code change we'll need to make is to update the prompt in our itinerary generator in the ViewModels folder and include our example. Let's go make this code change. We are back in our Xcode. I'm going to click on View Models and Itinerary Generator. I'm going to pull up my Find Navigator and click Section 3. You'll see the code change that we do need to make right here.

So within our Generate Itinerary function, we obviously define our prompt here and we're going to replace this prompt.

and I'm going to delete the previous prompt.

Again, just like what we used in the playground, we say let prompt equal to use a prompt builder API, pass this closure. This includes the same string that we previously had, but we also include this additional information whereby introduce Itinerary.exampleTripToJapan, which is of the type Itinerary. So not only does it include all the guidance, but also the schema that's part of this prompt now.

And because we made this change, we can get rid of this comment. And you'll notice that we made all the changes in chapter 3, which means we are ready to build and run this app. and take a look at the build app.

We can choose Serenity here, click on Generate Itinerary. We can ensure that the model will take the prompt, the instructions and the additional example, pass it to the model and generate our final output. There you go.

Okay, our app is working great. Let's close this and head on over to our slides. So in this chapter, we focused on prompting techniques. We learned how to use a prompt builder to construct prompts dynamically and saw how you can use one-shot prompting to improve the quality and consistency of the model's output. We then applied this by updating our app to include a detailed example in our prompt. While @Generable enforces the structure, the one-shot example teaches the model about relationship and the style within the structure.

The model also uses the provided example for the desired tone of voice, ensuring that the generated text aligns with the tone you want to set for the app.

While the difference in output may not always be dramatic, it's an important way to significantly improve the quality of your generated content. And that wraps up our section on prompting techniques.

This is a great place to pause. Let's take a quick 10 minute break. Feel free to use this time to catch up on the code, grab a coffee or stretch your legs. When we get back, we have some really exciting topics ahead. We'll make a UI update in real time with streaming, extend the model's capabilities with tool calling and wrap up with performance optimizations. We'll be back in 10 minutes. See you soon.

Welcome back everyone. I hope you had a great break. Let's keep going. With our high quality prompts in place, let's enhance the user experience by streaming the response in real time. In this chapter, we'll focus on refactoring our itinerary generator to use the streaming API to improve the user experience by streaming the model's response. We'll see how to handle partially generated content as the model is generating the response. We'll then update our view to render the itinerary as it's being generated, providing for a much responsive feel. So let's head on over to our guide. We're now in chapter four, streaming responses. Our goal in this chapter is to dramatically improve the user experience by streaming responses and showing the itinerary as it is being generated. We'll start by updating the itinerary generator file. This section doesn't include a playground component because it's easy to appreciate the streaming responses directly in the app. So let's head on over to our Xcode and open up itinerary generator.

We'll again use our find navigator, update to chapter four and take a look at all the code changes we need to make starting with itinerary. The first change we'll need to make is update our itinerary variable to be of the type Itinerary.partiallyGenerated.

So what is partiallyGenerated? Think of this as a mirror version of our struct where every single property is an optional. @Generable defines this automatically for us. It's a perfect way to represent data that arrives over time. So that is the first code change. I'm going to remove the comment here.

And the next code change we'll need to make is down here. So recall, our generate itinerary function included this async call to Session.respond, we passed our prompt, and then we passed our generable, and then we received our output. What we want instead is the model to generate responses and stream the responses to us. So what we are going to do is replace this code with a new API called Session.streamResponse. Let's take a look.

So we replaced Session.response with Session.streamResponse and kept the rest of the argument same. So you still pass in a prompt, you still provide the generating argument with the itinerary. But we don't have an await here. What we get instead is an async sequence called stream, which means we can then loop over it and assign all the outputs to our itinerary, which includes all these options. So we say try await partial response in stream, and we can extract it using partialresponse.content where you'll get a snapshot every time of whatever has been generated at that point in time. Because we made this code change, I'm going to remove this comment as well.

Okay, that includes all the code changes we need to make to our itinerary generator. So let's head on over to our Code Along Guide and move on to section 4.2. Now we are ready to update our views. Since partially generated fields are optionals, we can use if let statements to safely unwrap these options. And that is what we are going to do in this section. So we'll update our itinerary view, which we previously just got a preview in an earlier chapter, but now we are going to actually go make code changes to this. So let's head on over to Xcode, click on the views folder and click on itinerary view.

Okay, at the very top, you'll notice that we have itinerary, so we should also update this with the partially generated type that we also defined in our view model. And we need to make this code change to all the generables that we have here. So not only itinerary, but all the nested generables too. So if you scroll all the way down, if you recall, we have our day view, which includes a day plan, which should also be partially generated. And each time I make this code change, I'm going to remove these comments and further down, you'll also remember we have our activity array, and we are going to do the same to that.

Okay, so that is the primary code change to the generables. Let's go back all the way up to the top and you'll see Xcode is complaining about a few other things. So the other code change we'll need to make is, if you recall, I said these are optional, so we have to unwrap them. So let's go and do that.

So here is what I did. I said if let title equal to itinerary.title, If let is a great way to deal with these optionals. And because I have a title here, I don't need to extract it from itinerary. So I remove that. So that takes care of title. Now I need to repeat the same step for our description.

I use if let and update the text view to include description.

And then I need to repeat this again for rationale.

And I need to do this again for the other fields, which is days.

Okay, so you get the gist. So we have to keep doing this for all the itinerary fields that properties that we are accessing to safely unwrap them. Now I'm going to do something that I've been asking all of you to do all this while, which is go back to our Code Along Guide here and copy the completely updated file and paste it here because we have to do this for every single property. If you scroll here, you see in step three, we says repeat this for all these properties. So we changed title description rationale, but you have to do this for all the day plan and the activity views too. So instead, what I'm going to do right now in this code along is click on the show updated views, which includes all the code changes. So what I'm going to do is click on this copy button on the top right and go back to our Xcode itineraryview.swift file and just replace all the code with the updated code. And you can see in our find navigator that we don't have any more comments so we've made all the code changes. So I showed you a few different code changes that we need to make but you have to do the same for every single property. So that concludes all the code changes for chapter 4. So to quickly recap, we spoke about the changes we need to make to view model, which is used partially generated, and we updated our views to unwrap these options. So we're now ready to run this app. Click on run, it will build and run this app. And we have our app right here. I'm going to click on Sahara Desert here and click generate itinerary. Unlike previously where it was an async call, now we are able to stream responses as it is being generated. This has great user experience because someone using the app can start consuming this content even before all of the itinerary has been loaded.

Awesome. In this chapter, we made a big leap in user experience. We refactored our app to use a streaming API and learn how to work with partially generated content in our view model. And finally, we updated our view to display the itinerary as it is being generated in real time. That wraps up chapter four on streaming responses. Now our app is looking great but let's make it even smarter by giving the model new capabilities with tool calling. First let me introduce the concept of tool calling. In addition to what you provide to the prompt the model brings its own core knowledge from its training data but remember the model is built into the OS and its knowledge is frozen in time. So For example, if you ask it about weather in Cupertino right now, there's no way for it to know what that information is. To handle cases where you need real time or dynamic data, the framework supports tool calling. Here's how it works. We have a session transcript.

If you provided tools to the session, the session will present the tool definition to the model along with the instructions. In our example, the prompt tells the model which destination we want to visit.

Now, if the model decides that calling a tool can enhance the response, it will produce one or more tool calls. In this example, the model produces two tool calls, querying restaurants and hotels.

At this phase, the Foundation Models Framework will automatically call the code you wrote for these tools. The framework then automatically inserts the tool outputs back into the session transcript.

Finally, the model will incorporate the tool output and everything else in the transcript into the final response.

As we've seen so far, the model can be very creative, often giving a slightly different itinerary each time we make a request. While this randomness is great for creativity, it can be a challenge when we need predictable For an advanced feature like tool calling, especially when testing and debugging, we need to ensure that the model behaves consistently. We want to guarantee that it will call our tool when we expect it to. To achieve this, we are going to make another small change to our request using generation options API to use greedy sampling. Greedy sampling tells the model to stop being creative and to always pick the most obvious next token. This makes the models output deterministic. For our app, this ensures that the model will reliably call our tool every single time.

In this chapter, we'll take a look at a tool that can find points of interest. We'll then provide this tool to our language model session and instruct the model how to use it.

Back in the app, we'll integrate this tool into our itinerary generator to get real world data into our itineraries. Let's head on over to our Code Along Guide. We are now in chapter five, tool calling.

Our itinerary contains model generated hotel and restaurant names, and these may not be up to date. Our goal is to give the model a tool it can use to call a Swift code and fetch hotel and restaurant names that we've provided.

Let's go make these code changes to first build a tool and later use this tool in our app. I'll head on over to Xcode and click on our ViewModels folder and you'll see a new file here that says Find Points of Interest Tool.

Click on that. So here we have a class called Find Points of Interest Tool that conforms to the tool protocol, which means we have to define a few properties here that will go through step by step. So let's start making these code changes and I'll explain what is going on. The first change we'll need to make is to add a name and description for our tool. So I'm going to do that here.

So we provide our tool with a name which is find points of interest and a description which is find points of interest for a landmark. This is critical for the model to understand when to invoke this tool. So it will use the name and the description to determine when to invoke this tool. The next change we'll need to make is down here where let me pull up our find navigator so we can see all the code changes that we need to be making. Next code change we need to make here is to define the categories that the tool can search for points of interest for and we'll do that by introducing this generable enum. So The category is an enum that includes hotels and restaurants. This can of course include other cases like museums or campgrounds and others. We're going to use this in our next code chain which is to update our arguments.

Here we have an argument struct here. Let's update this and I'll talk about what this does.

the argument struct, I have a property here that says let point of interest and it is of type category which is something we just defined. So this point of interest could be a hotel or a restaurant and we also provide a guide. The guide has a description that says this is the type of destination to look for. So this argument is the contract between the tool and the model. When the model wants to invoke the tool, it will pass this argument to the tool so that the tool has access to whether it's a hotel or a restaurant that it wants the response from the tool, the category that it wants the response from the tool.

We've updated the argument. And now we're going to update our call function right here.

This function is the heart of our tool. It receives the arguments, performs an action, and returns an output that gets added back into the session's transcript for the model to see and use. So let's make this change.

Okay. And I'll go through step by step what's going on here.

First, I say let results equal to await get suggestions. We have not defined this. We'll define this in a moment. Essentially, think of this as a function that the call method can invoke in order to get these specific points of interest. And then the results will be part of the output here, which you can then, as you see in the return statement, we can insert this result as a string output back to be provided back to the model. The model then uses that information along with the prompts and instructions to generate the final response. So, the last code change we need to make, of course, is to define this function. I have a placeholder function here called getSuggestions. Let's update this.

All right. So within getSuggestions, I have a switch block here which takes in a category and then if it's a restaurant, it can return restaurant1, restaurant2 or restaurant3. Similarly, if it's a hotel, it can return hotel one, hotel two, or hotel three. Now, these are, for this demo, we are using hardcoded data. In a real app, this is where you would call APIs like MapKit or a server-side API to fetch real live data.

Okay, so we made all the code changes to our tool, which means we have fully defined our tool. Let's head on over back to our Code Along Guide and move on to section 5.2.

So what we're going to do now is test this tool. So we'll head on over to our playground and provide this tool to the model and take a look at the results. Again, like before, feel free to copy paste this and I'm going to step through each of these lines of code and explain what exactly is happening. So back in our Xcode, I'm going to switch over to Playground.swift file. And for this section, I'm going to just clean up the previous code and start from scratch.

Okay, so we have our empty playground here.

First, I'm going to add instructions.

Here, a neat feature of playground is that it has access to all the data structures in your Xcode project. without having to build the app. So what I'm doing here is create a landmark variable that has access to the model data defined here under the models folder under model data dot Swift and I say model data dot landmark zero which means I'm going to access one of those landmarks that you see specifically we are going to access the first landmark and if you recall that is Sahara Desert. So you have access to the same list of landmarks that you get when you run the app. So we take that and then we just defined this Find Points of Interest tool right here in the ViewModels folder. So we are going to create an instance of this tool and we can pass it the landmark because it uses that information. And finally, we have our instructions just like before. There are two minor code changes if you look carefully. One, it's no longer a string but instruction builder similar to prompt builder wherein we pass in a closure and provide our instructions. And the second key change you'll notice, very important for tool calling, is we say always use the find points of interest tool to find hotels and restaurants in this landmark. Now this instruction is telling the model that it must invoke this tool in order to get the points of interest response. Now we'll create a language model Session. Similar to previous code change, we said language model session and pasta instruction, but we do introduce a new argument called tools. Here tools can be an array of tools. We have only one tool here which is point of interest tool. Since it's an array, you can provide multiple tools so the model can reason about your prompts and instructions and decide which tool to call when and get back the response. So we've included our tool in our session. Next, we define a prompt. There are no changes to the prompt itself here. And finally, We will invoke the model.

No code changes here too, except we do introduce options that we briefly discussed in the slide. This generation option with sampling set to greedy will ensure that we always get consistent, repeatable and deterministic output given that the rest of the prompts and instructions are consistent. Okay, let's take a look at the canvas here and take a look at the output. Okay, we have our response generated and we have our content here.

So we have our title, description, rationale, days. Let me pick one of these days, day 0, arrival and let me take a look at the activities.

I'll open up activity 0, activity 1, and activity 2.

Now if you look closely, you'll see here under activity 1 description it says, "Enjoy a traditional Moroccan dinner at restaurant 1." You'll also see this in the title, "Dine-in at restaurant 1." And similarly, you see title for activity 2 here that says, "Stay in hotel 1 and unwind at hotel 1." This is the output of the tool that is being inserted into the output of the model. So the model took in a prompt instructions, the landmark name, invoke the tool, got back the hotel and restaurant names and inserted it back to the transcript and generated this response.

Let's take a look at the transcript itself.

So what I'm doing here is just creating a temporary variable for the session itself and capturing it into inspect session. The reason I'm doing this is to take a closer look at the session and transcript and we can see the tool calls being placed. Okay. So we have our inspect session, which we just created.

Now we are going to take a look at these properties. you see tools. It has one tool that we provided. And if you look at transcript, it has six elements in this entries. And here we have our instructions, which is always the very first entry in the transcript. And then we have a prompt, which is our initial request. And then we have tool calls. The model autonomously decided that it needs to call our tool. Then we have our tool outputs. The framework executed our tool and inserted these tool outputs back into the transcript. And then finally we have our response. The model synthesized the original prompt, the tool output data to generate this final response. There are two tool calls here because we are requesting for both restaurants as well as hotels. And you'll see this under the tool calls. So there's a request for a restaurant and a hotel.

Awesome. Let's head back to our Code Along Guide.

So now that we know how a tool works, we defined the tool, we tested the tool in our playground, We're now ready to update our itineraryGenerator.swift file to incorporate our tool into the app. That's what we'll do in section 5.3. We'll make our code changes to itineraryGenerator.swift. Feel free to copy and paste this into your files. The key changes as you see here we'll be making is to update our instructions, create an instance of tool, and also pass it to our language model session. Let's head on over to Xcode and open up our itineraryGenerator.swift. I'll also bring up my find navigator, set this to chapter 5 and we'll start making code changes.

So the first change we need to do is of course update our instructions.

I'm going to delete the previous instructions because I have this new instructions which includes point of interest tool that we defined and this additional text that is asking the model to call this tool in order to get the points of interest. And we also of course need to update the language model session using the tools argument. And since it can accept multiple tools it is an array and and we'll pass in the tool.

Okay, so that is the two code changes that we need to make in our initializer. And we did that, so I'm gonna get rid of these comments so we can track our changes. Okay, the final change we need to make is in the generate itinerary method here.

Recall, we mentioned that if we want get deterministic outputs, we can use greedy sampling. By default, it does random sampling. So right here, after in this session.stream response, after we pass the prompt, after we pass the generating argument, we can pass our options. Let me clean this up so it's easy for everyone to read.

All right, so we have our Session.streamResponse, we have a prompt, we have our generating argument, and finally we have our options which includes generation options and we use sampling and set it to greedy. Okay, so that concludes all the code changes that we need to make. Let's ensure we get rid of this comment.

There you go. If you don't see anything for chapter 5 in your Find Navigator, that means we've made all the code changes, we are ready to build and run this app.

Click on the run button, this will build and run this app.

And here is our app. Let's go through the standard user flow, which is click on Sahara Desert. I see a generate itinerary button. I click on that. Now this includes a streaming API along with our tools and it takes our instructions, our prompts, sends it to the model along with the tool definition. And as you see here, you can see stay at hotel one and dine in at restaurant one. These were responses from the tool that were inserted back into the session transcript and the model used all the information from the instructions, the prompts, the tool calls, The tool responses, package all of it, synthesized it, and is able to generate the output in the format of the generable, itinerary generable.

Fantastic. All right, let's go back to our slides and recap. So in this chapter, we gave the model powers with tool calling. We discussed a custom tool with its own arguments and call function. We learned how to provide the tool to the language model session, and importantly, how to instruct the model on when and how to use the tool. Finally, we integrated our tool into the app to fetch points of interest and include them in the generated itinerary. That wraps up chapter five on tool calling.

Before we wrap up this code along, let's look at a couple of key techniques to optimize performance and make our generative features feel more responsive.

Let's head on over to a Code Along Guide and move on to chapter six, Performance and Optimization.

Our app is now feature complete, but to make our app performant, we first need to understand where the bottlenecks are. We can't optimize what we can't measure. For this, we will use a powerful developer tool called Instruments.

Let's head on over to Xcode.

We'll do something slightly different now. If you long press on the run button here, you'll see a few different options. You see run, test, profile and analyze. So I'm going to click profile. What this does is it'll build the app and then launch up Xcode instruments.

Let's wait for it to finish building and there it is. So this is Xcode Instruments. We'll choose the blank template and then once you have your instruments open, I'm going click on this plus symbol here and search for foundation models. Okay, we are now ready to profile our app. I'm gonna click on the record and this will launch our app and we will use this app like we usually do. So as a user, Sahara Desert looks interesting. I read the title description, looks good. I click on generate itinerary and I see this nice itinerary come up. The results are being streamed to me. I can read through this, take a look at all the different activities that plan. Okay, I'm going to stop recording. Now let's take a closer look at what we have here in the instruments. Okay, there are a few different tracks here and I'll explain what is going on in each of these to identify any potential bottlenecks that we can address. First track here is response. The blue bar here represents entire session. So this is ever since the user clicks on generate itinerary, we create a session and the model takes in the instructions, prompts and generates output. All of this is represented by this blue bar. The second row here is asset loading. Here if you take a closer look, you'll see that once the session starts, there is a little bit of a delay and then the models are loaded here, the model assets, which means all this time from the start of the session all the way to end of loading the model, the model is not generating any responses and roughly looks like this is about 700 milliseconds, which is almost a full second, right? And then if you look at the third track, this is where you see that the first token is generated, which means it waits for all the the models to be loaded and then it starts the token generation process, starting with the first token and continues to generate all the responses. So there is an opportunity for performance improvement here. If we could load these assets ahead of time, maybe we could start this generation process as soon as the session starts.

So that is one bottleneck we can try and address. The second bottleneck, if you look at the bottom here, I'm going to choose the inference section here. If you take a closer look, you will see here that there is max token count. And we see here that this currently amounts to 1044. And this token count includes everything we've added into the session. This includes your instructions, your prompts, your tools. It includes the generables with the itinerary, all of it. So it includes all of this here and we can see if there's an opportunity to reduce this because the number of tokens has an implication on the model's performance. So that is a second bottleneck that we can see if we can try and address.

Okay. If you recall, when we call Session.respond, the OS will load the model if it's not already in memory.

pre-warming can give your session a head start by loading the model before you even make a request. In our app, when someone taps on the landmark, it's pretty likely that they are going to make a request soon. We can pre-warm before they press the generate itinerary button to proactively load the model. By the time they finish reading the description, our model will be ready to go.

Let's also look at another optimization that can reduce request latency. Recall that generable structs provided to the model can help generate structured outputs, but this comes at the cost of increased token count, which affects initial processing time. Also recall that in Chapter 3, we passed an example itinerary called example trip to Japan. Since our instructions includes this full example of the generable schema, we can often exclude the schema definition itself from the front, which saves space and can speed up the model.

Thanks to Xcode instruments, we've identified the bottlenecks in our app. Now, we'll implement some optimizations directly in the app. First, we'll pre-warm the session by calling the pre-warm method when the user taps on the landmark. This does the framework to start loading the model before the user even asks for the itinerary. Second, because our one-shot example is quite detailed, the full schema definition in the prompt is redundant. We can remove it by setting include schema and prompt to false. In our stream response call, we'll make this change. This will significantly reduce our input token count. Let's head on over to our Code Along Guide and take a look at the code changes we'll be making. We're now in chapter 6, the app section. The first part is to pre-warm the model and the code changes will be reflected in the itinerary generator where we'll add a function to pre-warm and then in the view as well so that we can call the pre-warm method when the view is loaded. So let's go make these changes in itinerary generator and landmark trip view. Let's head on over to Xcode. I'll keep the instrument open because I do want to check the effect of these optimizations. So I'm going to go to Xcode, click on itinerary generator. This is already open for us. And I'm going to use the find navigator to open chapter 6.

Okay.

The first change we'll make to PREWARM is to add the PREWARM code here. We've defined this placeholder function called PREWARM model. So all I'm going to do here is call the pre-womp method in the session.

It's as easy as that.

Now we have a function that we can invoke from our view that will pre-womp the model. If you ahead of time know what the prompt is going to be, you can also use a prompt prefix to update a pre-womp method.

So inside a Session.prewarm function, there is an optional argument called prompt prefix where you can provide a prompt so the model has knowledge of the prompt that the user might provide and it can prewarm using this. So here we pass a prompt with a closure that says generate a three-day itinerary to landmark.name. This can further improve performance.

Okay, the next code change we need to make is actually in landmark trip view. So in our views folder, we have our landmark trip view.

Here, we need to update our task in order to call the pre-warm method when the model is actually loaded. So let's do this here.

Again, this is as simple as calling the generator.prewarmModel function that we just defined. So that includes all the code changes for prewarming the model. Let's head back to our Code Along Guide and take a look at the second optimization that we discussed, which is to reduce the max token count. So we're now in section 6.2, where we'll optimize the prompt.

The code change we'll need to make here is again in itinerary generator. So we'll include this additional argument called include schema in prompt and set it to false. Let's make this change and I'll briefly again explain what is going on.

So back to our itinerary generator.

Here we have our Session.stream response where we pass in the prompt, the generable, and options. So we'll also include our new argument called include schema in prompt and set it to false. Now what this tells the model is that we can exclude the schema of the itinerary that we pass because we are already passing the example trip to Japan in instruments, which includes the golden example along with the structure. So we can skip including the schema which will help in reducing the maximum token count. Because we made this change, I'm going to get rid of this comment too.

Okay, that concludes all the changes in chapter 6, which means we are now ready to profile the app once again. Okay, let's do this again. So I'm going to click on the profile option again and again this will build the app and launch up our profiler in a moment.

You see Xcode is building, launched up our profiler again. Now when I record it will relaunch the app and we'll go through the same process again of using the app. Click record. I have my app here. I'm going to follow the same exact steps. I'm going to click on Sahara Desert. I'll read the title. The description looks good to me. I want to generate the itinerary and I see the itinerary being generated. Looks good. We have our day-by-day plan, what restaurants to eat in, what hotels to stay. We'll let it finish executing and I'm going to stop profiling. Let's do the same thing we did previously and take a look at the output and see what effect our optimizations have had on the app. The very first thing you should notice is that asset loading happened well before the session started thanks to our pre-warm function. So we loaded this asset at this point when the user clicked on the detail view we called the pre-warm method by adding the pre-warm function in the task which means by the time the user used to read the title and description, the model was already loaded and ready. And if you take a closer look at the start of the session here, you'll see that the output starts generating almost as soon as the session started. So the session started because the model has already been loaded. It starts to prepare the vocabulary, it starts generating the tokens and your responses are now much quicker. Let's also take a look at the second optimization that we did and what effect it has had. So down here under inference you'll see the maximum token count has dropped to 700. Previously it was 1000 so we have dropped the maximum token count to 700 by excluding the schema from the prompt. Now this also means that the model is able to much quickly process the initial token and start generating responses a lot quicker. Awesome. So in this last chapter we looked at performance. We learned how to pre-warm the model to make our app feel more responsive and how to optimize a prompt by excluding the schema when it's not needed. These are two simple but effective ways to improve the performance of your generative features. Now let's take one final look at that app we've built together. Let's go back to Xcode and build and run. Okay, so this should look familiar to you as it's the app running on your machine. We started with this simple Swift list of landmarks and when we select Serengeti here we see this detail view. Now let's tap on generate itinerary one last time.

The UI builds itself in real time. That's the streaming API from chapter four using Session.stream response and partially generated content. In chapter two, we used add generable to get this rich structured response. And in chapter five, we use tool calls to find these points of interest, which the model intelligently decided to call to get this data.

Okay, we've covered a lot today from basic text generation to guided generation, streaming, tool calling, and performance optimizations, but there's still more to explore. We didn't have time to cover some advanced topics such as training custom model adapters, dynamic runtime schemas, or diving into guardrails and error handling. To learn more about these topics, I highly recommend watching other WWDC25 videos on the Foundation Models Framework.

Looking at Slido, there are a lot of great questions here and if we didn't get to yours, please bring them to the developer forums at developer.apple.com/forums where we can continue this discussion. The completed sample project from today, including few additional features is available for download in the Foundation Models Framework documentation. Finally, you'll receive a survey later today. We hope you enjoyed the session and we'd appreciate your feedback. With that, thank you so much for coding along with me. We'll see you again soon. Bye.