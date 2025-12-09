# Bring advanced speech-to-text to your app with SpeechAnalyzer

Discover the new SpeechAnalyzer API for speech to text. We'll learn about the Swift API and its capabilities, which power features in Notes, Voice Memos, Journal, and more. We'll dive into details about how speech to text works and how SpeechAnalyzer and SpeechTranscriber can enable you to create exciting, performant features. And you'll learn how to incorporate SpeechAnalyzer and live transcription into your app with a code-along.

### Chapters

- 0:00 - [Introduction](https://developer.apple.com/videos/play/wwdc2025/277/?time=0)
- 2:41 - [SpeechAnalyzer API](https://developer.apple.com/videos/play/wwdc2025/277/?time=161)
- 7:03 - [SpeechTranscriber mode](https://developer.apple.com/videos/play/wwdc2025/277/?time=423)
- 9:06 - [Build a speech-to-text feature](https://developer.apple.com/videos/play/wwdc2025/277/?time=546)

### Resources

- [Bringing advanced speech-to-text capabilities to your app](https://developer.apple.com/documentation/Speech/bringing-advanced-speech-to-text-capabilities-to-your-app)
- [Speech](https://developer.apple.com/documentation/Speech)
- [HD Video](https://devstreaming-cdn.apple.com/videos/wwdc/2025/277/4/9eedc53d-668f-48f3-9cca-4f2530bbb2ce/downloads/wwdc2025-277_hd.mp4?dl=1)
- [SD Video](https://devstreaming-cdn.apple.com/videos/wwdc/2025/277/4/9eedc53d-668f-48f3-9cca-4f2530bbb2ce/downloads/wwdc2025-277_sd.mp4?dl=1)

### Related Videos

#### WWDC23

- [Extend Speech Synthesis with personal and custom voices](https://developer.apple.com/videos/play/wwdc2023/10033)

## Transcript

Hello! I’m Donovan, an engineer on the Speech framework team and I’m Shantini, an engineer on the Notes team. This year, we’re excited to bring you the next evolution of our speech-to-text API and technology: SpeechAnalyzer. In this session, we’ll discuss the SpeechAnalyzer API and its most important concepts. We’ll also briefly discuss some of the new capabilities of the model behind the API. And finally, we’ll show a live-coding demo of how to use the API. SpeechAnalyzer is already powering features across many system apps, such as Notes, Voice Memos, Journal, and more.

And when we combine SpeechAnalyzer with Apple Intelligence, we create incredibly powerful features such as Call Summarization. Later, I’ll show you how to use the API to build your own live transcription feature. But first, Donovan will give you an overview of the new SpeechAnalyzer API. Speech-to-text, also known as automatic speech recognition or ASR, is a versatile technology that allows you to create great user experiences using live or recorded speech by converting it to a textual form that a device can easily display or interpret. Apps can store, search, or transmit that text in real time or pass it on to a text-based large language model.

In iOS 10, we introduced SFSpeechRecognizer. That class gave you access to the speech-to-text model powering Siri. It worked well for short-form dictation and it could use Apple servers on resource-constrained devices but it didn’t address some use cases as well as we, or you, would have liked and relied on the user to add languages. So now, in iOS 26, we’re introducing a new API for all our platforms called SpeechAnalyzer that supports more use cases and supports them better. The new API leverages the power of Swift to perform speech-to-text processing and manage model assets on the user’s device with very little code. Along with the API, we’re providing a new speech-to-text model that is already powering application features across our platforms. The new model is both faster and more flexible than the one previously available through SFSpeechRecognizer. It’s good for long-form and distant audio, such as lectures, meetings, and conversations. Because of these improvements, Apple is using this new model (and the new API) in Notes and the other applications we mentioned earlier. You can use these new capabilities to build your own application with the same sort of speech to-text features that Notes and our other applications provide but first, let’s check out the design of the API. The API consists of the SpeechAnalyzer class along with several other classes. The SpeechAnalyzer class manages an analysis session. You can add a module class to the session to perform a specific type of analysis. Adding a transcriber module to the session makes it a transcription session that performs speech-to-text processing. You pass audio buffers to the analyzer instance, which then routes them through the transcriber and its speech-to-text model. The model predicts the text that corresponds to the spoken audio and returns that text, along with some metadata, to your application.

This all works asynchronously. Your application can add audio as it becomes available in one task and display or further process the results independently in another task. Swift’s async sequences buffer and decouple the input and results.

The “Meet AsyncSequence” session from WWDC21 covers how to provide an input sequence and how to read the results sequence.

To correlate the input with the results, the API uses the timecode of the corresponding audio. In fact, all API operations are scheduled using timecodes on the audio timeline, which makes their order predictable and independent of when they’re called. The timecodes are precise down to an individual audio sample. Note how the transcriber delivers results in sequence, each of which covers its own range of audio without overlapping. This is normally how it works but, as an optional feature, you can make transcription iterative within a range of audio. You may want to do this to provide more immediate feedback in your application’s UI. You can show a rough result immediately and then show better iterations of that result over the next few seconds. We call the immediate rough results "volatile results". They’re delivered almost as soon as they’re spoken but they are less accurate guesses. However, the model improves its transcription as it gets more audio with more context. Eventually, the result will be as good as it can be, and the transcriber delivers one last finalized result. Once it does that, the transcriber won’t deliver any more results for this range of audio, and it moves on to the next range. Note how the timecodes show that later, improved results replace earlier results. This only happens when you enable volatile results. Normally, the transcriber only delivers finalized results, and none of them replace earlier results. You can build a transcription feature in just one function if all you need to do is read the file and return the transcription. That’s a job that doesn’t need volatile result handling or much concurrency. Here’s the function. Here, we create the transcriber module. We tell it the locale that we want to transcribe into. It doesn’t have any results yet but we’ll read them as they come in and use the AsyncSequence version of reduce to concatenate them. We’ll do this in the background using async let. Here, we create the analyzer and add the transcriber module, then we start analyzing the file. The analyzeSequence method reads from the file and adds its audio to an input sequence. When the file has been read, we tell the analyzer to finish up because we aren’t planning to work on any additional audio. Finally, we return the transcription that we’ve been assembling in the background. That’ll be the spoken words in the file, in the form of a single attributed string, and we’re done.

So now I’ve covered the concepts and basic usage of the API. You add modules to an analysis session to perform, say, transcription. It works concurrently and asynchronously, decoupling audio input from results. You correlate audio, results, and operations using the session’s audio timeline. Some of those results are volatile, if you want them to be, and the rest are final and won’t change. And I showed how the pieces fit together in a one-function use case. Later, Shantini will demonstrate how you can expand that one function’s work across different views, models, and view models. She’ll show you several methods and properties of the SpeechAnalyzer and Transcriber classes that you can use to handle some common needs, and you can read about these in the documentation as well. But now, we’d like to describe some of the advantages of the SpeechTranscriber class’s new speech-to-text model. SpeechTranscriber is powered by a brand new model engineered by Apple to support a broad spectrum of use cases. We wanted to create a model that could support long-form and conversational use cases where some speakers might not be close to the mic, such as recording a meeting. We also wanted to enable live transcription experiences that demand low latency without sacrificing accuracy or readability, and we wanted to keep speech private. Our new, on-device model achieves all of that. We worked closely with internal partners to design a great developer experience for you, and now you can support the same use cases in your own applications. With SpeechTranscriber, you gain a powerful speech-to-text model that you don’t have to procure and manage yourself. Simply install the relevant model assets via the new AssetInventory API. You can download them when needed. The model is retained in system storage and does not increase the download or storage size of your application, nor does it increase the run-time memory size. It operates outside of your application’s memory space, so you don’t have to worry about exceeding the size limit. And we constantly improve the model, so the system will automatically install updates as they become available. SpeechTranscriber can currently transcribe these languages, with more to come, and is available for all platforms but watchOS with certain hardware requirements. If you need an unsupported language or device, we also offer a second transcriber class: DictationTranscriber. It supports the same languages, speech-to-text model, and devices as iOS 10’s on-device SFSpeechRecognizer but improving on SFSpeechRecognizer, you will NOT need to tell your users to go into Settings and turn on Siri or keyboard dictation for any particular language. So that’s your introduction to the new API and model. It was pretty abstract, but we’ll get concrete now. Let’s go to Shantini, who will show you how to integrate SpeechAnalyzer into your app. Thanks for that great overview, Donovan! You may have seen the amazing features that we added to Notes in iOS 18 to record and transcribe phone calls, live audio, and recorded audio. Additionally, we integrated these features with Apple Intelligence, resulting in useful and time-saving summaries. We worked closely with the Speech team to ensure that SpeechAnalyzer and SpeechTranscriber would enable us to deliver a high-quality Notes feature. SpeechTranscriber is a great fit because it’s fast, accurate even at longer distances, and on device. One of our additional goals was to enable you, the developer, to build features just like the ones we added to Notes and customize them to meet the needs of your users. I’d love to get you started with that. Let’s check out an app I’m building with a live transcription feature. My app is meant for kids and records and transcribes bedtime stories, allowing you to play them back. Here are the transcription results in real time.

And, when you play the audio back, the corresponding segment of text is highlighted, so that they can follow along with the story. Let’s check out the project setup.

In my sample app code, I have a Recorder class, and a SpokenWordTranscriber class. I’ve made them both observable.

I also made this Story model to encapsulate our transcript information and other relevant details for display. Finally, I have our transcript view, with live transcription and playback views, and recording and playback buttons. It also handles recording and playback state. Let’s first check out transcription. We can set up live transcription in 3 easy steps: configure the SpeechTranscriber; ensure the model is present; and handle the results. We set up our SpeechTranscriber by initializing it with a locale object and options that we need. The locale’s language code corresponds to the language in which we want to receive transcription. As Donovan highlighted before, volatile results are realtime guesses, and finalized results are the best guesses. Here, both of those are used, with the volatile results in a lighter opacity, replaced by the finalized results when they come in. To configure this in our SpeechTranscriber, we’re going to set these option types. I'm adding the audioTimeRange option so that we get timing information.

That will allow us to sync the playback of the text to the audio.

There are also pre-configured presets that offer different options.

We’re now going to set up the SpeechAnalyzer object with our SpeechTranscriber module.

This unlocks the ability for us to get the audio format that we need to use.

We're also now able to ensure our speech-to-text model is in place.

To finish up our SpeechTranscriber setup, we want to save references to the AsyncStream input and start the analyzer.

Now that we’re done setting up the SpeechTranscriber, let’s check out how we get the models. In our ensure model method, we're going to add checks for whether SpeechTranscriber supports transcription for the language we want.

We’ll also check whether the language is downloaded and installed.

If the language is supported but not downloaded, we can go ahead and make a request to AssetInventory to download support.

Remember that transcription is entirely on device but the models need to be fetched. The download request includes a progress object that you can use to let your user know what’s happening.

Your app can have language support for a limited number of languages at a time. If you exceed the limit, you can ask AssetInventory to deallocate one or more of them to free up a spot.

Now that we’ve gotten our models, let’s get to the fun part - the results.

Next to our SpeechTranscriber setup code, I'm creating a task and saving a reference to it.

I'm also creating two variables to track our volatile and finalized results.

The SpeechTranscriber returns results via AsyncStream. Each result object has a few different fields.

The first one we want to get is text, which is represented by an AttributedString. This is your transcription result for a segment of audio. Each time we get a result back in the stream, we'll want to check whether it’s volatile or finalized by using the isFinal property.

If it’s volatile, we’ll save it to volatileTranscript.

Whenever we get a finalized result, we clear out the volatileTranscript and add the result to finalizedTranscript.

If we don’t clear out our volatile results, we could end up with duplicates.

Whenever we get a finalized result, I'm also going to write that out to our Story model to be used later.

I'm also setting some conditional formatting using the SwiftUI AttributedString APIs.

This will allow us to visualize the transcription results as they transition from volatile to finalized.

If you’re wondering how I’ll get the timing data of the transcript, it’s conveniently part of the attributed string.

Each run has an audioTimeRange attribute represented as CMTimeRange. I’ll use that in my view code to highlight the correct segment. Let’s next check out how to set up our audio input.

In my record function, which I call as the user presses Record, I'm going to request audio permission and start the AVAudioSession. We should also ensure that the app is configured to use the microphone in the project settings.

I am then going to call my setUpTranscriber function that we created before.

Finally, I'm going to handle input from my audio stream. Let’s check out how I set that up. A few things are happening here. We’re configuring the AVAudioEngine to return an AsyncStream and passing the incoming buffers to the stream.

We’re also writing the audio to disk.

Finally, we’re starting the audioEngine.

Back in my Record function, I am passing that AsyncStream input to the transcriber.

Audio sources have different output formats and sample rates. SpeechTranscriber gave us a bestAvailableAudioFormat that we can use.

I'm passing our audio buffers through a conversion step to ensure that the format matches bestAvailableAudioFormat.

I'll then route the AsyncStream to the inputBuilder object from the SpeechTranscriber. When we stop recording, we want to do a few things. I stopped the audio engine and the transcriber. It’s important to cancel your tasks and also to call finalize on your analyzer stream. This will ensure that any volatile results get finalized. Let's check out how we can connect all of this to our view.

My TranscriptView has a binding to the current story, and one to our SpokenWordTranscriber. If we’re recording, we show a concatenation of the finalized transcript with the volatile transcript that we’re observing from our SpokenWordTranscriber class. For playback, we show the final transcript from the data model. I’ve added a method to break up the sentences to make it visually less cluttered.

A key feature I mentioned was highlighting each word as it’s played back. I’m using some helper methods to calculate whether each run should be highlighted, based on its audioTimeRange attribute and the current playback time.

SpeechTranscriber’s accuracy is great for so many reasons, not least of which is the ability to use Apple Intelligence to do useful transformations on the output.

Here, I’m using the new FoundationModels API to generate a title for my story when it’s done. The API makes it super simple to create a clever title, so I don’t have to think of one! To learn more about the FoundationModels APIs, check out the session titled ‘Meet the Foundation Models Framework’ .

Let's see our feature in action! I'm going to tap the Plus button to create a new story.

Then, I’ll start recording. "Once upon a time in the mystical land of Magenta, there was a little girl named Delilah who lived in a castle on the hill. Delilah spent her days exploring the forest and tending to the animals there." When the user is done, they can play it back and each word is highlighted in time with the audio.

"Once upon a time, in the mystical land of Magenta, there was a little girl named Delilah who lived in a castle on the hill.

Delilah spent her days exploring the forest and tending to the animals there." SpeechAnalyzer and SpeechTranscriber enabled us to build a whole app with very little startup time. To learn more, check out the Speech Framework documentation, which includes the sample app that we just created. And that’s SpeechAnalyzer! We know you’ll build amazing features with it. Thanks so much for joining us!

## Code

5:21 - [Transcribe a file](https://developer.apple.com/videos/play/wwdc2025/277/?time=321)

```
// Set up transcriber. Read results asynchronously, and concatenate them together.
let transcriber = SpeechTranscriber(locale: locale, preset: .offlineTranscription)
async let transcriptionFuture = try transcriber.results
    .reduce("") { str, result in str + result.text }

let analyzer = SpeechAnalyzer(modules: [transcriber])
if let lastSample = try await analyzer.analyzeSequence(from: file) {
    try await analyzer.finalizeAndFinish(through: lastSample)
} else {
    await analyzer.cancelAndFinishNow()
}
    
return try await transcriptionFuture
```


11:02 - [Speech Transcriber setup (volatile results + timestamps)](https://developer.apple.com/videos/play/wwdc2025/277/?time=662)

```
func setUpTranscriber() async throws {
        transcriber = SpeechTranscriber(locale: Locale.current,
                                        transcriptionOptions: [],
                                        reportingOptions: [.volatileResults],
                                        attributeOptions: [.audioTimeRange])
    }
```


11:47 - [Speech Transcriber setup (volatile results, no timestamps)](https://developer.apple.com/videos/play/wwdc2025/277/?time=707)

```
// transcriber = SpeechTranscriber(locale: Locale.current, preset: .progressiveLiveTranscription)
```


11:54 - [Set up SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/?time=714)

```
func setUpTranscriber() async throws {
    transcriber = SpeechTranscriber(locale: Locale.current,
                                    transcriptionOptions: [],
                                    reportingOptions: [.volatileResults],
                                    attributeOptions: [.audioTimeRange])
    
    guard let transcriber else {
        throw TranscriptionError.failedToSetupRecognitionStream
    }

    analyzer = SpeechAnalyzer(modules: [transcriber])
}
```


12:00 - [Get audio format](https://developer.apple.com/videos/play/wwdc2025/277/?time=720)

```
func setUpTranscriber() async throws {
    transcriber = SpeechTranscriber(locale: Locale.current,
                                    transcriptionOptions: [],
                                    reportingOptions: [.volatileResults],
                                    attributeOptions: [.audioTimeRange])
    
    guard let transcriber else {
        throw TranscriptionError.failedToSetupRecognitionStream
    }

    analyzer = SpeechAnalyzer(modules: [transcriber])
    
    self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
}
```


12:06 - [Ensure models](https://developer.apple.com/videos/play/wwdc2025/277/?time=726)

```
func setUpTranscriber() async throws {
    transcriber = SpeechTranscriber(locale: Locale.current,
                                    transcriptionOptions: [],
                                    reportingOptions: [.volatileResults],
                                    attributeOptions: [.audioTimeRange])
    
    guard let transcriber else {
        throw TranscriptionError.failedToSetupRecognitionStream
    }

    analyzer = SpeechAnalyzer(modules: [transcriber])
    
    self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
    
    do {
        try await ensureModel(transcriber: transcriber, locale: Locale.current)
    } catch let error as TranscriptionError {
        print(error)
        return
    }
}
```


12:15 - [Finish SpeechAnalyzer setup](https://developer.apple.com/videos/play/wwdc2025/277/?time=735)

```
func setUpTranscriber() async throws {
    transcriber = SpeechTranscriber(locale: Locale.current,
                                    transcriptionOptions: [],
                                    reportingOptions: [.volatileResults],
                                    attributeOptions: [.audioTimeRange])
    
    guard let transcriber else {
        throw TranscriptionError.failedToSetupRecognitionStream
    }

    analyzer = SpeechAnalyzer(modules: [transcriber])
    
    self.analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
    
    do {
        try await ensureModel(transcriber: transcriber, locale: Locale.current)
    } catch let error as TranscriptionError {
        print(error)
        return
    }
    
    (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
    
    guard let inputSequence else { return }
    
    try await analyzer?.start(inputSequence: inputSequence)
}
```


12:30 - [Check for language support](https://developer.apple.com/videos/play/wwdc2025/277/?time=750)

```
public func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        guard await supported(locale: locale) else {
            throw TranscriptionError.localeNotSupported
        }
    }
    
    func supported(locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func installed(locale: Locale) async -> Bool {
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }
```


12:39 - [Check for model installation](https://developer.apple.com/videos/play/wwdc2025/277/?time=759)

```
public func ensureModel(transcriber: SpeechTranscriber, locale: Locale) async throws {
        guard await supported(locale: locale) else {
            throw TranscriptionError.localeNotSupported
        }
        
        if await installed(locale: locale) {
            return
        } else {
            try await downloadIfNeeded(for: transcriber)
        }
    }
    
    func supported(locale: Locale) async -> Bool {
        let supported = await SpeechTranscriber.supportedLocales
        return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }

    func installed(locale: Locale) async -> Bool {
        let installed = await Set(SpeechTranscriber.installedLocales)
        return installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
    }
```


12:52 - [Download the model](https://developer.apple.com/videos/play/wwdc2025/277/?time=772)

```
func downloadIfNeeded(for module: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            self.downloadProgress = downloader.progress
            try await downloader.downloadAndInstall()
        }
    }
```


13:19 - [Deallocate an asset](https://developer.apple.com/videos/play/wwdc2025/277/?time=799)

```
func deallocate() async {
        let allocated = await AssetInventory.allocatedLocales
        for locale in allocated {
            await AssetInventory.deallocate(locale: locale)
        }
    }
```


13:31 - [Speech result handling](https://developer.apple.com/videos/play/wwdc2025/277/?time=811)

```
recognizerTask = Task {
            do {
                for try await case let result in transcriber.results {
                    let text = result.text
                    if result.isFinal {
                        finalizedTranscript += text
                        volatileTranscript = ""
                        updateStoryWithNewText(withFinal: text)
                        print(text.audioTimeRange)
                    } else {
                        volatileTranscript = text
                        volatileTranscript.foregroundColor = .purple.opacity(0.4)
                    }
                }
            } catch {
                print("speech recognition failed")
            }
        }
```


15:13 - [Set up audio recording](https://developer.apple.com/videos/play/wwdc2025/277/?time=913)

```
func record() async throws {
        self.story.url.wrappedValue = url
        guard await isAuthorized() else {
            print("user denied mic permission")
            return
        }
#if os(iOS)
        try setUpAudioSession()
#endif
        try await transcriber.setUpTranscriber()
                
        for await input in try await audioStream() {
            try await self.transcriber.streamAudioToTranscriber(input)
        }
    }
```


15:37 - [Set up audio recording via AVAudioEngine](https://developer.apple.com/videos/play/wwdc2025/277/?time=937)

```
#if os(iOS)
    func setUpAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
#endif
    
    private func audioStream() async throws -> AsyncStream<AVAudioPCMBuffer> {
        try setupAudioEngine()
        audioEngine.inputNode.installTap(onBus: 0,
                                         bufferSize: 4096,
                                         format: audioEngine.inputNode.outputFormat(forBus: 0)) { [weak self] (buffer, time) in
            guard let self else { return }
            writeBufferToDisk(buffer: buffer)
            self.outputContinuation?.yield(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        return AsyncStream(AVAudioPCMBuffer.self, bufferingPolicy: .unbounded) {
            continuation in
            outputContinuation = continuation
        }
    }
```


16:01 - [Stream audio to SpeechAnalyzer and SpeechTranscriber](https://developer.apple.com/videos/play/wwdc2025/277/?time=961)

```
func streamAudioToTranscriber(_ buffer: AVAudioPCMBuffer) async throws {
        guard let inputBuilder, let analyzerFormat else {
            throw TranscriptionError.invalidAudioDataType
        }
        
        let converted = try self.converter.convertBuffer(buffer, to: analyzerFormat)
        let input = AnalyzerInput(buffer: converted)
        
        inputBuilder.yield(input)
    }
```


16:29 - [Finalize the transcript stream](https://developer.apple.com/videos/play/wwdc2025/277/?time=989)

```
try await analyzer?.finalizeAndFinishThroughEndOfInput()
```

## Summary

- 0:00 - [Introduction](https://developer.apple.com/videos/play/wwdc2025/277/?time=0)
- Apple is introducing SpeechAnalyzer, a new speech-to-text API and technology in iOS 26, replacing SFSpeechRecognizer introduced in iOS 10. SpeechAnalyzer, built with Swift, is faster, more flexible, and supports long-form and distant audio, making it suitable for various use cases such as lectures, meetings, and conversations. The new API enables you to create live transcription features and is already powering system apps like Notes, Voice Memos, and Journal. When combined with Apple Intelligence, it facilitates powerful features like Call Summarization.

- 2:41 - [SpeechAnalyzer API](https://developer.apple.com/videos/play/wwdc2025/277/?time=161)
- The API design centers around the SpeechAnalyzer class, which manages analysis sessions. By adding a transcriber module, the session becomes a transcription session capable of performing speech-to-text processing. Audio buffers are passed to the analyzer instance, which routes them through the transcriber's speech-to-text model. The model predicts text and metadata, which are returned asynchronously to the application using Swift's async sequences. All API operations are scheduled using timecodes on the audio timeline, ensuring predictable order and independence. The transcriber delivers results in sequence, covering specific audio ranges. An optional feature allows iterative transcription within a range, providing immediate, though less accurate, "volatile results" for faster UI feedback, which are later refined into finalized results. Looking forward in this presentation, a use case is discussed that demonstrates how to create a transcriber module, set the locale, read audio from a file, concatenate results using async sequences, and return the final transcription as an attributed string. The API enables concurrent and asynchronous processing, decoupling audio input from results, and can be expanded to handle more complex needs across different views, models, and view models, which is demonstrated later.

- 7:03 - [SpeechTranscriber mode](https://developer.apple.com/videos/play/wwdc2025/277/?time=423)
- Apple developed a new speech-to-text model for the SpeechTranscriber class, designed to handle various scenarios such as long-form recordings, meetings, and live transcriptions with low latency and high accuracy. The model operates entirely on-device, ensuring privacy and efficiency. It does not increase the app's size or memory usage and automatically updates. You can easily integrate the model into your applications using the AssetInventory API. The SpeechTranscriber class currently supports several languages and is available across most Apple platforms, with a fallback option, DictationTranscriber, provided for unsupported languages or devices.

- 9:06 - [Build a speech-to-text feature](https://developer.apple.com/videos/play/wwdc2025/277/?time=546)
- In iOS 18, the Notes app has been enhanced with new features that allow people to record and transcribe phone calls, live audio, and recorded audio. These features are integrated with Apple Intelligence to generate summaries. The Speech team developed SpeechAnalyzer and SpeechTranscriber, enabling high-quality, on-device transcription that is fast and accurate, even at distances. You can now use these tools to create your own customized transcription features. An example app is designed for kids; it records and transcribes bedtime stories. The app displays real-time transcription results and highlights the corresponding text segment during audio playback. To implement live transcription in an app, follow three main steps: configure the SpeechTranscriber with the appropriate locale and options, ensure the necessary speech-to-text model is downloaded and installed on the device, and then handle the transcription results as they are received via an AsyncStream. The results include both volatile (realtime guesses) and finalized text, allowing for smooth syncing between text and audio playback. When a finalized result is obtained, the 'volatileTranscript' is cleared, and the result is added to the 'finalizedTranscript' to prevent duplicates. The finalized result is also written to the Story model for later use and visualized with conditional formatting using SwiftUI AttributedString APIs. Set up audio input by requesting permission, starting the 'AVAudioSession', and configuring the AVAudioEngine to return an AsyncStream. The audio is written to disk and passed to the transcriber after being converted to the best available audio format. Upon stopping recording, the audio engine and transcriber are stopped, and any volatile results are finalized. The 'TranscriptView' displays the concatenation of finalized and volatile transcripts during recording and the final transcript from the data model during playback, with words highlighted in time with the audio. In the example app, Apple Intelligence is utilized to generate a title for the story using the FoundationModels API showing how you can use Apple Intelligence to perform useful transformations on the speech-to-text output. The Speech Framework enables the development of this app with minimal startup time, and further details can be found in its documentation.