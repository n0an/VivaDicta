# Explore prompt design & safety for on-device foundation models

Design generative AI experiences that leverage the strengths of the Foundation Models framework. We'll start by showing how to design prompts for the on-device large language model at the core of Apple Intelligence. Then, we'll introduce key ideas around AI safety, and offer concrete strategies to make your generative AI features safe, reliable, and delightful.

### Chapters

- 0:00 - [Introduction](https://developer.apple.com/videos/play/wwdc2025/248/?time=0)
- 2:30 - [Design for on-device LLM](https://developer.apple.com/videos/play/wwdc2025/248/?time=150)
- 6:14 - [Prompting best practices](https://developer.apple.com/videos/play/wwdc2025/248/?time=374)
- 11:03 - [AI safety](https://developer.apple.com/videos/play/wwdc2025/248/?time=663)
- 18:37 - [Evaluate and test](https://developer.apple.com/videos/play/wwdc2025/248/?time=1117)

### Resources

- [Adding intelligent app features with generative models](https://developer.apple.com/documentation/FoundationModels/adding-intelligent-app-features-with-generative-models)
- [Human Interface Guidelines: Generative AI](https://developer.apple.com/design/human-interface-guidelines/generative-ai)
- [Human Interface Guidelines: Machine learning](https://developer.apple.com/design/human-interface-guidelines/machine-learning)
- [Improving safety from generative model output](https://developer.apple.com/documentation/FoundationModels/improving-safety-from-generative-model-output)
- [HD Video](https://devstreaming-cdn.apple.com/videos/wwdc/2025/248/7/5f4b2840-b27c-42a1-992f-179475029fb9/downloads/wwdc2025-248_hd.mp4?dl=1)
- [SD Video](https://devstreaming-cdn.apple.com/videos/wwdc/2025/248/7/5f4b2840-b27c-42a1-992f-179475029fb9/downloads/wwdc2025-248_sd.mp4?dl=1)

## Transcript

Hi, I’m Mary Beth. I’m a researcher of human-centered AI. And I’m Sprite. I’m an AI safety engineer. We’ve made it easier than ever to design generative AI experiences for your app using the new Foundation Models framework. Generative AI is an exciting technology. The key challenge is to create a robust experience that works for people using your app in different real-world situations. Luckily, Mary Beth and I have guidance to help you. Totally. Whether you’re a designer or an engineer, this talk is for you.

Before we get started, let’s take a quick moment to orient ourselves with prompts and LLMs.

As you may know, a prompt is a text input to a generative AI model to guide its response. Written in a natural human language like you’re messaging a human coworker.

Here, I’ve written a prompt as a string variable that says: "Generate a bedtime story about a fox." Notice, I’ve written this prompt in English, but you can write prompts in any language supported by Apple Intelligence.

Next, let’s look at the code to run my prompt against a language model session. When I run this, the model responds with a detailed, imaginative bedtime story. Incredible! Let’s take a closer look at what’s going on here. With the new Foundation Models Framework, your prompt is sent to an on-device Large Language Model, or LLM.

LLMs can reason about and generate text. This model is general purpose and built into the operating systems on iOS, iPadOS, MacOS, and VisionOS.

In fact, this same language model is used by Apple Intelligence for things like writing tools. Under the hood, Apple Intelligence also uses prompting to instruct the model. Now that we’ve got a sense of prompts and LLMs, let’s get into what we’ll cover in this talk. First, I’ll walk through some design strategies specific to the on-device language model you’ll be using, and then cover prompting best practices. Later, Sprite will walk us through designing for AI safety, ending with strategies for evaluating and testing your prompts for quality and safety. Let's get started.

First, let’s dig into design for the on-device LLM. This model lives on your devices and can be used for lots of common language tasks, like summarization, classification, multi-turn conversations, text composition, text revision, and generating tags from text. But keep in mind that this large language model is optimized and compressed to fit in your pocket. The on-device model is around 3 billion parameters. Now, 3 billion, by any other measure, is still a huge machine learning model.

But to put it into perspective, imagine this circle is a popular LLM you’ve heard of, like ChatGPT.

Currently, LLMs like this are hundreds of billions of parameters in size and run on massive servers. Today, this difference in size means that the on-device LLM won’t be able to do everything a big server-based LLM can do.

First, tasks that work with a large-scale LLM may not work as is with a smaller model. If you’re not getting good results with a system model for a complex reasoning task, try breaking down your task prompt into simpler steps.

For math-related tasks, you’re gonna wanna avoid asking this small model to act as a calculator. Non-AI code is much more reliable for math.

The system model is not optimized for code, so avoid code generation tasks as well.

Next, due to its smaller size, the system model has limited world knowledge. For example, the model won’t know about recent events that occurred after its training date. Don’t rely on the system model for facts unless you’ve thoroughly verified that the model knows about a specific topic, like bagels. I’ll ask the model to list out 10 popular bagel flavors.

And this is what the model produces for my prompt. It's clear the model knows bagels, but it describes a plain bagel as having a ton of toppings, which is incorrect. This model shouldn’t be used as a bagel encyclopedia because it's not fully accurate. But this level of knowledge may be suitable for some things, like a bakery game.

For example, you can use the model to generate dialogue for customers ordering bagels.

If the model makes a mistake, a weird bagel flavor might be funny in a game rather than misleading.

Next, it’s vital to understand the impacts of hallucinations. For knowledge the model doesn’t know, it may hallucinate, which is the technical word for completely making up an answer. In places like instructions where facts are critical, don’t risk hallucinations misleading people.

Avoid relying on the system language model for facts. If you do want to generate facts, consider providing the model with verified information written into your prompt. And thoroughly fact check model outputs for any new prompts you write.

For now, you can improve reliability in many situations with a special feature of this model: Guided generation. With the Foundation Models Framework, Guided generation gives you control over what the model should generate, whether that be strings, numbers, arrays, or a custom data structure that you define. For more on how guided generation works, check out the Meet Foundation Models Framework talk.

Next, let’s talk about some prompting best practices. Prompt engineering is a big topic. I encourage you to study beyond this talk. But here are a few best practices to get you started. First, you can control the amount of content the system model generates simply by telling the model. My prompt says, “Generate a bedtime story about a fox.” I’ll change my prompt to ask for just one paragraph.

And that works! A much shorter bedtime story. Use phrases like “in three sentences” or “in a few words” to shorten output. Use phrases like “in detail” to generate longer output.

Next, you can control the style and voice of text the model produces by specifying a role in your prompt. I’ll tell the model that it is a fox who speaks Shakespearean English.

And that works too. The model has successfully taken on the role of a Shakespearean fox, and has written a cute little diary entry as that character. The model can take on many roles based on your prompt.

I have some additional tips for you based on the way that this model has been trained. First, phrase your prompts as a clear command. Overall, the model will perform best when given a single specific task in detail. You can boost your task performance by giving the model less than five examples of the kinds of outputs you want, and just write those directly into your prompt. Finally, if you observe output you want to stop, the model will respond well to an all caps command: “DO NOT” kind of like talking to it in a stern voice.

When you're ready to start experimenting, a great place to try out prompts is the new Playgrounds feature in Xcode. Just add #Playground to any code file in your project and write your prompt with a language model session. The model’s response will immediately appear in the canvas on the right, just like a Swift UI preview. This is a great way to experiment to find out what prompt works best for your app. Now, our prompt engineering best practices can be applied to both prompts and instructions. Instructions are a second kind of prompt the Foundation Model’s framework offers that serves a slightly different purpose. When you create a language model session, you can include instructions as an argument. Instructions are a special kind of prompt that tells the model how it should behave and respond to all subsequent prompts. Here I wrote the instructions: “You are a helpful assistant who generates scary stories appropriate for teenagers.” Let's see its effect.

Our original bedtime story generation with a simple prompt, looked like this.

When we add instructions, the model receives our instructions first before any other prompt.

Now, when we send our prompt to generate a bedtime story, the tone of the bedtime story drastically changes to match our instruction that the story be scary.

Note we can continue to prompt the model and the instructions will hold.

Now I’ll send a prompt, “Write a poem about bagels.” As expected, the model produces a spooky, scary poem about bagels. Let’s wrap up our discussion of prompts with a note on interactivity. Prompts don’t only need to come from you as the app designer. Using instructions and prompts together, you can create an interactive model session where prompts come from people using your app. Let's take a look. Let's imagine I'm building a diary app. First, I’ll give the language model these instructions.

“You are a helpful assistant who helps people write diary entries by asking them questions about their day.” Now I want someone using my app to be able to start their diary entry directly as a prompt to my model. They say, “Ugh, today was rough.” Now the model responds with a diary prompt. “What made today rough?” In this scenario, if you take input from people as a prompt to your model, you don’t know what people will input. Prompts impact safety. Whether accidentally or on purpose, someone could provide an input that causes the model to respond in unhelpful or even harmful ways. For more on AI safety, here’s Sprite, and she could share more. Thank you, Mary Beth. She has shown you how you can write great prompts to get the best out of our on-device model.

Prompt design is the first tool in your safety toolbox. Let’s learn more about how to design your app with safety in mind. We’ve created a set of principles for our Apple Intelligence features to reflect our core values. We follow the same principles when designing the Foundation Models framework to help you create a magical and safe experience for your app. We want to enable you to create apps that empower people. Whether it is generating bedtime stories for kids or planning for the next dream vacation. Generative AI can be misused or lead to potential harm. While the Foundation Models framework has guardrails to help you create a safe app experience, I encourage you to also consider what could go wrong for the use case of your app. We designed our model and the framework with privacy in mind, and we are continuously improving our model to avoid perpetuating stereotypes and systemic biases. Now let's talk about guardrails. The Foundation Models framework comes with guardrails trained by Apple, so you don’t have to worry about the worst.

Guardrails are applied to both the input and the output of the model. Your instructions, prompts, and tool calls are all considered inputs to the model. We designed our guardrails to block inputs containing harmful contents.

The output of the model is also protected by the guardrails. This makes sure harmful model outputs are blocked, even if the prompts were crafted to bypass input guardrails.

This is how you can catch safety errors in Swift. When an error occurs, you need to think about how to communicate this back to people using your app.

If your feature is proactive, or in other words, not driven by user action, you can simply ignore the error and not interrupt the UI with unanticipated information.

For a user-initiative feature, especially one that has someone wait, remember to provide appropriate UI feedback to explain that the app cannot process the request. It can be a simple alert, or you can use this opportunity to provide alternative actions for people to choose from. For example, Image Playground provides an easy way for people to undo the prompt that caused the safety error.

The Foundation Models framework gives you a great starting point, but you are still responsible for the experience in your app. So that people can trust it to generate appropriate content to fulfill their expectations.

Here are three elements of building trust with people using your app.

Make sure your app does not generate inappropriate content. The guardrails in the Foundation Models framework will block them.

You will also need to handle user input with care. You can achieve this by carefully writing your instructions and prompts.

Also think about what happens when people act on the responses from your app, and how it may impact them. I will give you a few examples later to help you think about what you can do.

Let's return to the same diary example that Mary Beth showed earlier. Our model is trained to obey instructions over prompts. So instructions are a great place to improve the safety of responses.

Here, I’m appending a sentence to tell the model to respond to negative prompts in an empathetic and wholesome way. With that, you can see how the new instructions steer the model output. Even though this is not bulletproof, carefully written safety instructions improve the quality of responses in your app.

It is very important to make sure the instructions only come from you and never include untrusted content or user input. Instead, you can include user input in your prompts. Let's take a look. One very common pattern is taking the user input directly as prompts.

Think of a chatbot that takes any input from people using your app. This pattern has a lot of flexibility, but it also carries safety risks. When you need this pattern, make sure you have instructed the model to handle a wide range of user input with care.

One good way to reduce risks without sacrificing flexibility is to combine your own prompt with the user input.

Or even better, your app can provide a list of built-in prompts for people to choose from, so you have complete control over the prompts. While this is not as flexible as other patterns, it allows you to curate a set of prompts that truly shine for your app and for the model to generate great responses.

Even with great instructions and careful handling of user’s input, your app may still have safety risks.

You have to anticipate the impact and consequences when people take action on generating content in your app.

Let’s look at some examples.

This is the prompt for generating bagel flavors that Mary Beth showed you earlier.

One potential risk when people use your app is that some of the bagel flavors from the model can contain allergens like nuts or garlic.

One way you can mitigate this is by showing an allergy warning in the UI.

Or you can also add settings, so people can set their dietary restrictions for your app to filter recipes from the model.

Another example is if you are building a trivia generation app, where you may want to avoid generating questions about controversial or foreign topics that are not appropriate for the audience.

Consider adding additional instructions or coming up with a denying list of keywords.

If you are an ML practitioner, you can also train a classifier for a more robust solution.

Ultimately, you are responsible for applying mitigations for your own use case. Like many other safety systems, what we have discussed so far is a layering-based approach to make sure a safety problem can only occur when all layers fail to catch the issue.

You can imagine the layers as a stack of Swiss cheese slices. Even though each slice has holes in them, the holes in the whole stack will have to line up for something to fall through.

Now, let’s reveal our safety toolbox.

The foundational layer of our stack is the built-in guardrails in the Foundation Models framework. You will be adding safety in your instructions to the model.

These instructions will take precedence over prompts. You will also be designing your app to control how to include user inputs in prompts to your model.

Finally, the last layer, you would implement your own use case mitigation.

Another crucial step in building an app that uses generative AI is evaluation and testing.

You can start by curating datasets for both quality and safety.

Remember to collect prompts to cover all major use cases of your app, and you will also need to collect prompts that may trigger safety issues.

With a dataset, you will design an automation to run them through your feature end to end.

It would be a good idea to create a dedicated command line tool or a UI tester app for this purpose.

For a small dataset, you can inspect each response manually to see if there are issues.

If you want to scale this to a larger dataset, you can explore using another large language model to automatically grade the responses for you.

And don’t forget to test the unhappy path in your app to make sure the behavior of your app is what you expect when there are safety errors.

Investing in evaluation and testing can help you track improvements or regressions over time as you update your prompts and also as we update our model. This helps you to be confident in the quality and safety of the intelligent feature in your app.

We will continue to update our model and safety system to follow the latest best practices and resolve safety issues. If you encounter safety issues when you are developing your app, You can report them using feedback assistance.

You can also create your own UI to collect user feedback for your app features. When doing that, make sure people understand what data is collected from your app and how it is used.

You can learn more about data collection and privacy for your app on our developer website. We've covered a lot in this video. Let’s wrap up the safety topic by giving you a checklist for you to consider.

Your app should handle guardrail errors when prompting the model. Safety should be part of your instructions.

When including user input in your prompts, think about how you can balance between flexibility and safety. Anticipate impact when people use your intelligence features and apply use case specific mitigations.

Invest in evaluation and testing so you can be confident in the quality and safety of the intelligence feature in your app.

And finally, report safety issues using feedback assistance.

That's a wrap for AI safety. We can't wait to see what you create with Generative AI in your app. I’ll leave you with some extra resources and tools to help.

Remember, try out the new Xcode inline playgrounds feature for your prompt engineering. While we’ve shared a bunch of recommendations for safety in your app, you can find out more about Apple’s approach to responsible AI, including our Foundation Model’s built-in safety mitigations, with an in-depth article on machinelearning.apple.com. And finally, check out our new generative AI design guidelines and the Human Interface Guidelines. And that's prompting and safety. Happy prompting! But remember, safety first!