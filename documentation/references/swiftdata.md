<!--
Downloaded via https://llm.codes by @steipete on June 15, 2025 at 01:06 PM
Source URL: https://developer.apple.com/documentation/swiftdata/
Total pages processed: 292
URLs filtered: Yes
Content de-duplicated: Yes
Availability strings filtered: Yes
Comprehensive filtering: Yes
-->

# https://developer.apple.com/documentation/swiftdata/

Framework

# SwiftData

Write your model code declaratively to add managed persistence and efficient model fetching.

## Overview

Combining Core Data’s proven persistence technology and Swift’s modern concurrency features, SwiftData enables you to add persistence to your app quickly, with minimal code and no external dependencies. Using modern language features like macros, SwiftData enables you to write code that is fast, efficient, and safe, enabling you to describe the entire model layer (or object graph) for your app. The framework handles storing the underlying model data, and optionally, syncing that data across multiple devices.

SwiftData has uses beyond persisting locally created content. For example, an app that fetches data from a remote web service might use SwiftData to implement a lightweight caching mechanism and provide limited offline functionality.

SwiftData is unintrusive by design and supplements your app’s existing model classes. Attach the `Model()` macro to any model class to make it persistable. Customize the behavior of that model’s properties with the `Attribute(_:originalName:hashModifier:)` and `Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)` macros. Use the `ModelContext` class to insert, update, and delete instances of that model, and to write unsaved changes to disk.

To display models in a SwiftUI view, use the `Query()` macro and specify a predicate or fetch descriptor. SwiftData performs the fetch when the view appears, and tells SwiftUI about any subsequent changes to the fetched models so the view can update accordingly. You can access the model context in any SwiftUI view using the `modelContext` environment value, and specify a particular model container or context for a view with the `modelContainer(_:)` and `modelContext(_:)` view modifiers.

## Topics

### Essentials

Preserving your app’s model data across launches

Describe your model classes to SwiftData using the framework’s macros, and store instances of those models so they exist beyond the app’s runtime.

Adding and editing persistent data in your app

Create a data entry form for collecting and changing data managed by SwiftData.

Adopting SwiftData for a Core Data app

Persist data in your app intuitively with the Swift native persistence framework.

SwiftData updates

Learn about important changes to SwiftData.

Adopting inheritance in SwiftData

Add flexibility to your models using class inheritance.

### Model definition

`macro Model()`

Converts a Swift class into a stored model that’s managed by SwiftData.

`macro Attribute(Schema.Attribute.Option..., originalName: String?, hashModifier: String?)`

Specifies the custom behavior that SwiftData applies to the annotated property when managing the owning class.

Specifies the key-paths that SwiftData uses to enforce the uniqueness of model instances.

Specifies the key-paths that SwiftData uses to create one or more binary indices for the associated model.

Specifies the key-paths that SwiftData uses to create one or more indicies for the associated model, where each index is either binary or R-tree.

Defining data relationships with enumerations and model classes

Create relationships for static and dynamic data stored in your app.

`macro Relationship(Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule, minimumModelCount: Int?, maximumModelCount: Int?, originalName: String?, inverse: AnyKeyPath?, hashModifier: String?)`

Specifies the options that SwiftData needs to manage the annotated property as a relationship between two models.

`macro Transient()`

Tells SwiftData not to persist the annotated property when managing the owning class.

### Model life cycle

`class ModelContainer`

An object that manages an app’s schema and model storage configuration.

`class ModelContext`

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

`struct HistoryDescriptor`

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Reverting data changes using the undo manager

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

Syncing model data across a person’s devices

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

### Model fetch

Filtering and sorting persistent data

Manage data store presentation using predicates and dynamic queries.

`macro Query()`

Fetches all instances of the attached model type.

Supplementary macros that enable you to narrow query results and tell SwiftData how to sort and order those results.

`struct Query`

A type that fetches models using the specified criteria, and manages those models so they remain in sync with the underlying data.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

### Model storage

Maintaining a local copy of server data

Create and update a persistent store to cache read-only network data.

`class DefaultStore`

A data store that uses Core Data as its undelying storage mechanism.

`protocol DataStore`

An interface that enables SwiftData to read and write model data without knowledge of the underlying storage mechanism.

`protocol DataStoreBatching`

An interface that enables a custom data store to support batch requests.

`protocol HistoryProviding`

An interface that enables a custom data store to provide the history of changes for its persisted models.

Building a document-based app using SwiftData

Code along with the WWDC presenter to transform an app with SwiftData.

`struct ModelDocument`

A document type that uses SwiftData to manage its storage.

### History life cycle

`enum HistoryChange`

Values that describe data history transactions.

`protocol HistoryDelete`

An interface that enables a custom data store to delete items from the history of changes to its persisted models.

`protocol HistoryInsert`

`protocol HistoryToken`

`protocol HistoryTransaction`

`protocol HistoryUpdate`

`struct HistoryTombstone`

`struct DefaultHistoryInsert`

`struct DefaultHistoryUpdate`

`struct DefaultHistoryDelete`

`struct DefaultHistoryToken`

`struct DefaultHistoryTransaction`

### Codeable support

`enum DataStoreSnapshotCodingKey`

The key space to use when implementing custom coders and decoders for data store snapshots,

### Errors

`struct SwiftDataError`

A type that describes a SwiftData error.

`enum DataStoreError`

A type that describes a data store error.

---

# https://developer.apple.com/documentation/swiftdata

Framework

# SwiftData

Write your model code declaratively to add managed persistence and efficient model fetching.

## Overview

Combining Core Data’s proven persistence technology and Swift’s modern concurrency features, SwiftData enables you to add persistence to your app quickly, with minimal code and no external dependencies. Using modern language features like macros, SwiftData enables you to write code that is fast, efficient, and safe, enabling you to describe the entire model layer (or object graph) for your app. The framework handles storing the underlying model data, and optionally, syncing that data across multiple devices.

SwiftData has uses beyond persisting locally created content. For example, an app that fetches data from a remote web service might use SwiftData to implement a lightweight caching mechanism and provide limited offline functionality.

SwiftData is unintrusive by design and supplements your app’s existing model classes. Attach the `Model()` macro to any model class to make it persistable. Customize the behavior of that model’s properties with the `Attribute(_:originalName:hashModifier:)` and `Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)` macros. Use the `ModelContext` class to insert, update, and delete instances of that model, and to write unsaved changes to disk.

To display models in a SwiftUI view, use the `Query()` macro and specify a predicate or fetch descriptor. SwiftData performs the fetch when the view appears, and tells SwiftUI about any subsequent changes to the fetched models so the view can update accordingly. You can access the model context in any SwiftUI view using the `modelContext` environment value, and specify a particular model container or context for a view with the `modelContainer(_:)` and `modelContext(_:)` view modifiers.

## Topics

### Essentials

Preserving your app’s model data across launches

Describe your model classes to SwiftData using the framework’s macros, and store instances of those models so they exist beyond the app’s runtime.

Adding and editing persistent data in your app

Create a data entry form for collecting and changing data managed by SwiftData.

Adopting SwiftData for a Core Data app

Persist data in your app intuitively with the Swift native persistence framework.

SwiftData updates

Learn about important changes to SwiftData.

Adopting inheritance in SwiftData

Add flexibility to your models using class inheritance.

### Model definition

`macro Model()`

Converts a Swift class into a stored model that’s managed by SwiftData.

`macro Attribute(Schema.Attribute.Option..., originalName: String?, hashModifier: String?)`

Specifies the custom behavior that SwiftData applies to the annotated property when managing the owning class.

Specifies the key-paths that SwiftData uses to enforce the uniqueness of model instances.

Specifies the key-paths that SwiftData uses to create one or more binary indices for the associated model.

Specifies the key-paths that SwiftData uses to create one or more indicies for the associated model, where each index is either binary or R-tree.

Defining data relationships with enumerations and model classes

Create relationships for static and dynamic data stored in your app.

`macro Relationship(Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule, minimumModelCount: Int?, maximumModelCount: Int?, originalName: String?, inverse: AnyKeyPath?, hashModifier: String?)`

Specifies the options that SwiftData needs to manage the annotated property as a relationship between two models.

`macro Transient()`

Tells SwiftData not to persist the annotated property when managing the owning class.

### Model life cycle

`class ModelContainer`

An object that manages an app’s schema and model storage configuration.

`class ModelContext`

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

`struct HistoryDescriptor`

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Reverting data changes using the undo manager

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

Syncing model data across a person’s devices

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

### Model fetch

Filtering and sorting persistent data

Manage data store presentation using predicates and dynamic queries.

`macro Query()`

Fetches all instances of the attached model type.

Supplementary macros that enable you to narrow query results and tell SwiftData how to sort and order those results.

`struct Query`

A type that fetches models using the specified criteria, and manages those models so they remain in sync with the underlying data.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

### Model storage

Maintaining a local copy of server data

Create and update a persistent store to cache read-only network data.

`class DefaultStore`

A data store that uses Core Data as its undelying storage mechanism.

`protocol DataStore`

An interface that enables SwiftData to read and write model data without knowledge of the underlying storage mechanism.

`protocol DataStoreBatching`

An interface that enables a custom data store to support batch requests.

`protocol HistoryProviding`

An interface that enables a custom data store to provide the history of changes for its persisted models.

Building a document-based app using SwiftData

Code along with the WWDC presenter to transform an app with SwiftData.

`struct ModelDocument`

A document type that uses SwiftData to manage its storage.

### History life cycle

`enum HistoryChange`

Values that describe data history transactions.

`protocol HistoryDelete`

An interface that enables a custom data store to delete items from the history of changes to its persisted models.

`protocol HistoryInsert`

`protocol HistoryToken`

`protocol HistoryTransaction`

`protocol HistoryUpdate`

`struct HistoryTombstone`

`struct DefaultHistoryInsert`

`struct DefaultHistoryUpdate`

`struct DefaultHistoryDelete`

`struct DefaultHistoryToken`

`struct DefaultHistoryTransaction`

### Codeable support

`enum DataStoreSnapshotCodingKey`

The key space to use when implementing custom coders and decoders for data store snapshots,

### Errors

`struct SwiftDataError`

A type that describes a SwiftData error.

`enum DataStoreError`

A type that describes a data store error.

---

# https://developer.apple.com/documentation/swiftdata/model()

#app-main)

- SwiftData
- Model()

Macro

# Model()

Converts a Swift class into a stored model that’s managed by SwiftData.

Swift 5.9+

@attached(member, conformances: Observable, PersistentModel, Sendable, names: named(_$backingData), named(persistentBackingData), named(schemaMetadata), named(init), named(_$observationRegistrar), named(_SwiftDataNoType), named(access), named(withMutation)) @attached(memberAttribute) @attached(extension, conformances: Observable, PersistentModel, Sendable) macro Model()

## Mentioned in

Preserving your app’s model data across launches

## Overview

Annotate your model classes with the `@Model` macro to make them persistable. At build time, the macro expands to provide conformance to the `PersistentModel` and `Observable` protocols.

@Model
class RemoteImage {
var sourceURL: URL
var data: Data

init(sourceURL: URL, data: Data = Data()) {
self.sourceURL = sourceURL
self.data = data
}
}

For more information about defining models, see Preserving your app’s model data across launches.

## See Also

### Model definition

`macro Attribute(Schema.Attribute.Option..., originalName: String?, hashModifier: String?)`

Specifies the custom behavior that SwiftData applies to the annotated property when managing the owning class.

Specifies the key-paths that SwiftData uses to enforce the uniqueness of model instances.

Specifies the key-paths that SwiftData uses to create one or more binary indices for the associated model.

Specifies the key-paths that SwiftData uses to create one or more indicies for the associated model, where each index is either binary or R-tree.

Defining data relationships with enumerations and model classes

Create relationships for static and dynamic data stored in your app.

`macro Relationship(Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule, minimumModelCount: Int?, maximumModelCount: Int?, originalName: String?, inverse: AnyKeyPath?, hashModifier: String?)`

Specifies the options that SwiftData needs to manage the annotated property as a relationship between two models.

`macro Transient()`

Tells SwiftData not to persist the annotated property when managing the owning class.

---

# https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:)

#app-main)

- SwiftData
- Attribute(\_:originalName:hashModifier:)

Macro

# Attribute(\_:originalName:hashModifier:)

Specifies the custom behavior that SwiftData applies to the annotated property when managing the owning class.

Swift 5.9+

@attached(peer)
macro Attribute(
_ options: Schema.Attribute.Option...,
originalName: String? = nil,
hashModifier: String? = nil
)

## Parameters

`options`

A list of options to apply to the attached property to customize its behavior. For possible values, see `Schema.Attribute.Option`.

`originalName`

The previous name of the attribute, if it’s different to the one in the current schema version. The default value is `nil`.

`hashModifier`

A unique hash value that represents the most recent version of the attached property. The default value is `nil`.

## Mentioned in

Fetching and filtering time-based model changes

Preserving your app’s model data across launches

## Overview

The framework’s default behavior for managing a model class’s stored properties is suitable for most use cases. However, if you need to alter the persistence behavior of a particular property, annotate it with the `@Attribute` macro. For example, you may want to avoid conflicts in your model data by specifying that an attribute’s value is unique across all instances of that model.

@Model
class RemoteImage {
@Attribute(.unique) var sourceURL: URL
var data: Data

init(sourceURL: URL, data: Data = Data()) {
self.sourceURL = sourceURL
self.data = data
}
}

## See Also

### Model definition

`macro Model()`

Converts a Swift class into a stored model that’s managed by SwiftData.

Specifies the key-paths that SwiftData uses to enforce the uniqueness of model instances.

Specifies the key-paths that SwiftData uses to create one or more binary indices for the associated model.

Specifies the key-paths that SwiftData uses to create one or more indicies for the associated model, where each index is either binary or R-tree.

Defining data relationships with enumerations and model classes

Create relationships for static and dynamic data stored in your app.

`macro Relationship(Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule, minimumModelCount: Int?, maximumModelCount: Int?, originalName: String?, inverse: AnyKeyPath?, hashModifier: String?)`

Specifies the options that SwiftData needs to manage the annotated property as a relationship between two models.

`macro Transient()`

Tells SwiftData not to persist the annotated property when managing the owning class.

---

# https://developer.apple.com/documentation/swiftdata/relationship(_:deleterule:minimummodelcount:maximummodelcount:originalname:inverse:hashmodifier:)

#app-main)

- SwiftData
- Relationship(\_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)

Macro

# Relationship(\_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)

Specifies the options that SwiftData needs to manage the annotated property as a relationship between two models.

Swift 5.9+

@attached(peer)
macro Relationship(
_ options: Schema.Relationship.Option...,
deleteRule: Schema.Relationship.DeleteRule = .nullify,
minimumModelCount: Int? = 0,
maximumModelCount: Int? = 0,
originalName: String? = nil,
inverse: AnyKeyPath? = nil,
hashModifier: String? = nil
)

## Parameters

`options`

A list of options to apply to the annotated property to customize its behavior. For possible values, see `Schema.Relationship.Option`.

`deleteRule`

The rule to apply when you delete the relationship’s owning persistent model. For possible values, see `Schema.Relationship.DeleteRule`. The default value is `Schema.Relationship.DeleteRule.nullify`.

`minimumModelCount`

The minimum number of models the relationship can reference. The default value is `0`.

`maximumModelCount`

The maximum number of models the relationship can reference. The default value is `0`.

`originalName`

The previous name of the attribute, if it’s different to the one in the current schema version. The default value is `nil`.

`inverse`

The key path of the relationship that represents the inverse of this relationship. The default value is `nil`.

`hashModifier`

A unique hash value that represents the most recent version of the annotated property. The default value is `nil`.

## Mentioned in

Preserving your app’s model data across launches

## Overview

If one or more of a model’s properties represent relationships between their containing model and another model, annotate those properties with the `@Relationship` macro. This enables SwiftData to enforce those relationships at runtime — including what happens if you delete related data – as well as write any associated metadata to the persistent storage so the relationships exist across app launches.

In the following example, a remote image may belong to a category, and a category can contain zero, one, or more images.

@Model
class RemoteImage {
@Attribute(.unique) var sourceURL: URL
@Relationship(inverse: \Category.images) var category: Category?
var data: Data

init(sourceURL: URL, data: Data = Data()) {
self.sourceURL = sourceURL
self.data = data
}
}

@Model
class Category {
@Attribute(.unique) var name: String
@Relationship var images = RemoteImage

init(name: String) {
self.name = name
}
}

For more information about defining relationships between models, see Defining data relationships with enumerations and model classes.

## See Also

### Model definition

`macro Model()`

Converts a Swift class into a stored model that’s managed by SwiftData.

`macro Attribute(Schema.Attribute.Option..., originalName: String?, hashModifier: String?)`

Specifies the custom behavior that SwiftData applies to the annotated property when managing the owning class.

Specifies the key-paths that SwiftData uses to enforce the uniqueness of model instances.

Specifies the key-paths that SwiftData uses to create one or more binary indices for the associated model.

Specifies the key-paths that SwiftData uses to create one or more indicies for the associated model, where each index is either binary or R-tree.

Defining data relationships with enumerations and model classes

Create relationships for static and dynamic data stored in your app.

`macro Transient()`

Tells SwiftData not to persist the annotated property when managing the owning class.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext

- SwiftData
- ModelContext

Class

# ModelContext

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

Swift 5.9+

class ModelContext

## Mentioned in

Preserving your app’s model data across launches

## Overview

A model context is central to SwiftData as it’s responsible for managing the entire lifecycle of your persistent models. You use a context to insert new models, track and persist changes to those models, and to delete those models when you no longer need them. A context understands your app’s schema but doesn’t know about any individual models until you tell it to fetch some from the persistent storage or populate it with new models. Afterwards, any changes made to those models exist only in memory until the context implicitly writes them to the persistent storage, or you manually invoke `save()`. For more information about implicit writes, see `autosaveEnabled`.

If your app’s schema describes relationships between models, you don’t need to manually insert each model into the context when you first create them. Instead, create the graph of related models and insert only the graph’s root model into the context. The context recognizes the hierarchy and automatically handles the insertion of the related models. The same behavior applies even if the graph contains both new and existing models.

A model context depends on a model container for knowledge about your app’s schema and persistent storage. After you attach a container to your app’s window group or view hierarchy, an associated context becomes available in the SwiftUI environment. This context is bound to the main actor and the framework configures the context to implicitly save future model changes. The `Query()` macros use the same context to perform their fetches.

struct LastModifiedView: View {
@Environment(\.modelContext) private var modelContext

}

After you establish access to a model context, use that context’s `insert(_:)` and `delete(_:)` methods to add and remove models. You can also delete several models at once using `delete(model:where:includeSubclasses:)`. There isn’t a corresponding method to update a model because the context automatically tracks all changes to its known models. Use the `hasChanges` property to determine if the context has unsaved changes, and call `rollback()` to discard any pending inserts and deletes and any restore changed models to their most recent saved state.

Although you fetch models primarily with the `Query()` macro (and its variants), you can use a model context to perform almost identical fetches. For example, use the `fetch(_:)` and `fetch(_:batchSize:)` methods to retrieve all models of a certain type that match a set of criteria. And use `fetchCount(_:)` to determine the number of models that match some criteria without the overhead of fetching the models themselves. If you need to be able to identify models that match some criteria but don’t require all of the associated data, use `fetchIdentifiers(_:)` and `fetchIdentifiers(_:batchSize:)` to retrieve only those models’ persistent identifiers.

A model context posts a `willSave` notification before it attempts a save operation, and a `didSave` notification immediately after that operation succeeds. Subscribe to one, or both, of these notifications if your app needs to be aware of these events. The `didSave` notification provides additional information about any inserted, updated, and deleted models.

struct LastModifiedView: View {
@Environment(\.modelContext) private var context
@State private var lastModified = Date.now

private var didSavePublisher: NotificationCenter.Publisher {
NotificationCenter.default
.publisher(for: ModelContext.willSave, object: context)
}

var body: some View {
Text(lastModified.formatted(date: .abbreviated, time: .shortened))
.onReceive(didSavePublisher) { _ in
lastModified = Date.now
}
}
}

## Topics

### Creating a model context

`init(ModelContainer)`

Creates a context that belongs to the specified model container.

`class ModelContainer`

An object that manages an app’s schema and model storage configuration.

### Fetching models

Returns an array of typed models that match the criteria of the specified fetch descriptor.

Returns a collection of typed models, in batches, which match the criteria of the specified fetch descriptor.

Returns the number of models that match the criteria of the specified fetch descriptor.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

`struct FetchResultsCollection`

A collection that efficiently provides the results of a completed fetch.

Runs a closure for each model that matches the criteria of the specified fetch descriptor.

Returns the persistent model for the specified identifier.

Returns the typed model for the specified identifier.

### Inserting models

[`var insertedModelsArray: [any PersistentModel]`](https://developer.apple.com/documentation/swiftdata/modelcontext/insertedmodelsarray)

The array of inserted models that the context is yet to persist.

Registers the specified model with the context so it can include the model in the next save operation.

### Modifying models

`var hasChanges: Bool`

A Boolean value that indicates whether the context has unsaved changes.

[`var changedModelsArray: [any PersistentModel]`](https://developer.apple.com/documentation/swiftdata/modelcontext/changedmodelsarray)

The array of registered models that have unsaved changes.

### Deleting models

[`var deletedModelsArray: [any PersistentModel]`](https://developer.apple.com/documentation/swiftdata/modelcontext/deletedmodelsarray)

The array of registered models that the context will remove from the persistent storage during the next save operation.

Removes the specified model from the persistent storage during the next save operation.

Removes each model satisfying the given predicate from the persistent storage during the next save operation.

### Persisting unsaved changes

`var autosaveEnabled: Bool`

A Boolean value that indicates whether the context should automatically save any pending changes when certain events occur.

`func save() throws`

Writes any pending inserts, changes, and deletes to the persistent storage.

Runs the provided closure, and once it finishes, writes any pending inserts, changes, and deletes to the persistent storage.

`func rollback()`

Discards pending inserts and deletes, restores changed models to their most recent committed state, and empties the undo stack.

### Fetching only persistent identifiers

Returns an array of persistent identifiers, where each identifier represents a single model that satisfies the criteria of the specified fetch descriptor.

Returns a collection of persistent identifiers, in batches, where each identifier represents a single model that satisfies the criteria of the specified fetch descriptor.

### Accessing the container

`var container: ModelContainer`

The context’s model container.

### Performing undo and redo

`func processPendingChanges()`

Tells the undo manager to record any changes made to the context’s registered models.

`var undoManager: UndoManager?`

The object that provides undo support for the context.

### Registering for notifications

`static let willSave: Notification.Name`

A notification that posts when the context is about to process pending inserts, changes, and deletes.

`static let didSave: Notification.Name`

A notification that posts when the context finishes processing pending inserts, changes, and deletes.

`enum NotificationKey`

Describes the data in the user info dictionary of a notification sent by a model context.

### Comparing contexts

Returns a Boolean value indicating whether two values are equal.

### Debugging contexts

`var debugDescription: String`

A textual representation of the context, suitable for debugging.

### Instance Properties

`var author: String?`

`var editingState: EditingState`

## Relationships

### Conforms To

- `Equatable`

## See Also

### Model life cycle

Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

`struct HistoryDescriptor`

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Reverting data changes using the undo manager

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

Syncing model data across a person’s devices

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

---

# https://developer.apple.com/documentation/swiftdata/query()

#app-main)

- SwiftData
- Query()

Macro

# Query()

Fetches all instances of the attached model type.

SwiftDataSwiftUI

@attached(accessor) @attached(peer, names: prefixed(`_`))
macro Query()

## See Also

### Model fetch

Filtering and sorting persistent data

Manage data store presentation using predicates and dynamic queries.

Supplementary macros that enable you to narrow query results and tell SwiftData how to sort and order those results.

`struct Query`

A type that fetches models using the specified criteria, and manages those models so they remain in sync with the underlying data.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

---

# https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches

- SwiftData
- Preserving your app’s model data across launches

Article

# Preserving your app’s model data across launches

Describe your model classes to SwiftData using the framework’s macros, and store instances of those models so they exist beyond the app’s runtime.

## Overview

Most apps define a number of custom types that model the data it creates or consumes. For example, a travel app might define classes that represent trips, flights, and booked accommodations. Using SwiftData, you can quickly and efficiently persist that data so it’s available across app launches, and leverage the framework’s integration with SwiftUI to refetch that data and display it onscreen.

By design, SwiftData supplements your existing model classes. The framework provides tools such as macros and property wrappers that enable you to expressively describe your app’s schema in Swift code, removing any reliance on external dependencies such as model and migration mapping files.

### Turn classes into models to make them persistable

To let SwiftData save instances of a model class, import the framework and annotate that class with the `Model()` macro. The macro updates the class with conformance to the `PersistentModel` protocol, which SwiftData uses to examine the class and generate an internal schema. Additionally, the macro enables change tracking for the class by adding conformance to the `Observable` protocol.

import SwiftData

// Annotate new or existing model classes with the @Model macro.
@Model
class Trip {
var name: String
var destination: String
var startDate: Date
var endDate: Date
var accommodation: Accommodation?
}

By default, SwiftData includes all noncomputed properties of a class as long as they use compatible types. The framework supports primitive types such as `Bool`, `Int`, and `String`, as well as complex value types such as structures, enumerations, and other value types that conform to the `Codable` protocol.

The code you write to define your model classes now serves as the source of truth for your app’s model layer, and the framework uses that to keep the persisted data in a consistent state.

### Customize the persistence behavior of model attributes

An _attribute_ is a property of a model class that SwiftData manages. In most cases, the framework’s default behavior for attributes is sufficient. However, if you need to alter how SwiftData handles the persistence of a particular attribute, use one of the provided schema macros. For example, you may want to avoid conflicts in your model data by specifying that an attribute’s value is unique across all instances of that model.

To customize an attribute’s behavior, annotate the property with the `Attribute(_:originalName:hashModifier:)` macro and specify values for the options that drive the desired behavior:

@Attribute(.unique) var name: String

Aside from enforcing unique constraints, `@Attribute` supports, among others, preserving deleted values, Spotlight indexing, and encryption. You can also use the `@Attribute` macro to correctly handle renamed attributes if you want to preserve the original name in the underlying model data.

When a model contains an attribute whose type is also a model (or a collection of models), SwiftData implicitly manages the relationship between those models for you. By default, the framework sets relationship attributes to `nil` after you delete a related model instance. To specify a different deletion rule, annotate the property with the `Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)` macro. For example, you may want to delete any related accommodations when deleting a trip. For more information about delete rules, see `Schema.Relationship.DeleteRule`.

@Relationship(.cascade) var accommodation: Accommodation?

SwiftData persists all noncomputed attributes of a model by default, but you may not always want this to happen. For example, one or more properties on a class may only ever contain temporary data that doesn’t need saving, such as the current weather at an upcoming trip’s destination. In such scenarios, annotate those properties with the `Transient()` macro and SwiftData won’t write their values to disk.

@Transient var destinationWeather = Weather.current()

### Configure the model storage

Before SwiftData can examine your models and generate the required schema, you need to tell it — at runtime — which models to persist, and optionally, the configuration to use for the underlying storage. For example, you may want the storage to exist only in memory when running tests, or to use a specific CloudKit container when syncing model data across devices.

To set up the default storage, use the `modelContainer(for:inMemory:isAutosaveEnabled:isUndoEnabled:onSetup:)` view modifier (or the scene equivalent) and specify the array of model types to persist. If you use the view modifier, add it at the very top of the view hierarchy so all nested views inherit the properly configured environment:

import SwiftUI
import SwiftData

@main
struct TripsApp: App {
var body: some Scene {
WindowGroup {
ContentView()
.modelContainer(for: [\
Trip.self,\
Accommodation.self\
])
}
}
}

If you’re not using SwiftUI, create a model container manually using the appropriate initializer:

let container = try ModelContainer([\
Trip.self,\
Accommodation.self\
])

Alternatively, use `ModelConfiguration` to create custom storage. The type provides a number of options to configure including whether:

- the storage exists only in memory.

- the storage is read-only.

- the app uses a specific App Group to store its model data.

let configuration = ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: false)

let container = try ModelContainer(
for: Trip.self, Accommodation.self,
configurations: configuration
)

### Save models for later use

To manage instances of your model classes at runtime, use a _model context_ — the object responsible for the in-memory model data and coordination with the model container to successfully persist that data. To get a context for your model container that’s bound to the main actor, use the `modelContext` environment variable:

struct ContentView: View {
@Environment(\.modelContext) private var context
}

Outside of a view, or if you’re not using SwiftUI, access the same actor-bound context directly using the model container:

let context = container.mainContext

In both instances, the returned context periodically checks whether it contains unsaved changes, and if so, implicitly saves those changes on your behalf. For contexts you create manually, set the `autosaveEnabled` property to `true` to get the same behavior.

To enable SwiftData to persist a model instance and begin tracking changes to it, insert the instance into the context:

var trip = Trip(name: name,
destination: destination,
startDate: startDate,
endDate: endDate)

context.insert(trip)

Following the insert, you can save immediately by invoking the context’s `save()` method, or rely on the context’s implicit save behavior instead. Contexts automatically track changes to their known model instances and include those changes in subsequent saves. In addition to saving, you can use a context to fetch, enumerate, and delete model instances. For more information, see `ModelContext`.

### Fetch models for display or additional processing

After you begin persisting model data, you’ll likely want to retrieve that data, materialized as model instances, and display those instances in a view or take some other action on them. SwiftData provides the `Query` property wrapper and the `FetchDescriptor` type for performing fetches.

To fetch model instances, and optionally apply search criteria and a preferred sort order, use `@Query` in your SwiftUI view. The `@Model` macro adds `Observable` conformance to your model classes, enabling SwiftUI to refresh the containing view whenever changes occur to any of the fetched instances.

struct ContentView: View {
@Query(sort: \.startDate, order: .reverse) var allTrips: [Trip]

var body: some View {
List {
ForEach(allTrips) {
TripView(for: $0)
}
}
}
}

Outside of a view, or if you’re not using SwiftUI, use one of the two fetch methods on `ModelContext`. Each method expects an instance of `FetchDescriptor` containing a predicate and a sort order. The fetch descriptor allows for additional configuration that influences batching, offsets, and prefetching, among others.

sortBy: [\
.init(\.startDate)\
]
)
upcomingTrips.fetchLimit = 50
upcomingTrips.includePendingChanges = true

let results = context.fetch(upcomingTrips)

For more information about predicates, see `Predicate`.

## See Also

### Essentials

Adding and editing persistent data in your app

Create a data entry form for collecting and changing data managed by SwiftData.

Adopting SwiftData for a Core Data app

Persist data in your app intuitively with the Swift native persistence framework.

SwiftData updates

Learn about important changes to SwiftData.

Adopting inheritance in SwiftData

Add flexibility to your models using class inheritance.

---

# https://developer.apple.com/documentation/swiftdata/adding-and-editing-persistent-data-in-your-app

- SwiftData
- Adding and editing persistent data in your app

Sample Code

# Adding and editing persistent data in your app

Create a data entry form for collecting and changing data managed by SwiftData.

Download

Xcode 15.0+

## Overview

Adding and editing data are fundamental features of data-driven apps, but how an app provides these features is unique to the app. This sample shows one approach, which is to use a data-entry form with SwiftData that lets someone add, edit, and store data about animals.

### Define the data model

Before SwiftData can store data from your app, the app must define the data model that represents the data. SwiftData uses model classes to construct the schema of the data model. For example, the sample app stores data about animals, and groups those animals into categories. To define the schema for this data model, the sample defines two model classes: `Animal` and `AnimalCategory`.

The `Animal` model class stores information about an animal, like its name and diet. To persist instances of `Animal`, the class definition applies the `Model()` macro. This macro generates code at compile time that ensures the class conforms to the `PersistentModel` protocol and makes it possible for SwiftData to save animal data to a model container.

import SwiftData

@Model
final class Animal {
var name: String
var diet: Diet
var category: AnimalCategory?

init(name: String, diet: Diet) {
self.name = name
self.diet = diet
}
}

The `AnimalCategory` model class stores information about an animal category, such as mammal or reptile. As with `Animal`, the `AnimalCategory` definition applies the `Model()` macro to ensure the class conforms to `PersistentModel` and to save the animal category data to a model container.

@Model
final class AnimalCategory {
@Attribute(.unique) var name: String
// `.cascade` tells SwiftData to delete all animals contained in the
// category when deleting it.
@Relationship(deleteRule: .cascade, inverse: \Animal.category)
var animals = Animal

init(name: String) {
self.name = name
}
}

The model class also has two properties:

`name`

The name of the category. Each category name must be unique across all animal categories. To ensure this uniqueness, the model class applies the `Attribute(_:originalName:hashModifier:)` macro to the property with the option `unique`. This option ensures a property’s value is unique across all models of the same type. For a complete list of options, see `Schema.Attribute.Option`.

`animal`

The list of animals contained in the category. The model class applies the `Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)` macro to this property to form a relationship between the model classes `AnimalCategory` and `Animal`. To learn more about the relationship, see Defining data relationships with enumerations and model classes.

### Design the data editor

When deciding how people add and edit data in your app, consider the user experience. The sample app, for instance, lets someone add and edit information about animals using a custom data entry view, named `AnimalEditor`.

The design of `AnimalEditor` allows the app to use the same view for both adding new animals and editing existing ones. To provide this behavior, the editor declares the `animal` property as an optional `Animal` type. If `animal` is `nil`, a person using the editor is adding an animal; otherwise, the person is editing an existing animal. The editor makes the intention obvious by determining the title of the editor based on the value of `animal` in a computed property.

struct AnimalEditor: View {
let animal: Animal?

private var editorTitle: String {
animal == nil ? "Add Animal" : "Edit Animal"
}
// ...
}

To enable editing the values of a new or existing animal, the editor defines state variables for each editable value. These state variables store the data that a person enters into the editor, separating what they enter from the data stored in `animal`. This separation ensures that SwiftData doesn’t save changes that a person makes until they’re ready to save those changes. This also gives them an opportunity to discard any changes they may have made to the data in the editor.

@State private var name = ""
@State private var selectedDiet = Animal.Diet.herbivorous
@State private var selectedCategory: AnimalCategory?

var body: some View {
NavigationStack {
Form {
TextField("Name", text: $name)

Picker("Category", selection: $selectedCategory) {
Text("Select a category").tag(nil as AnimalCategory?)
ForEach(categories) { category in
Text(category.name).tag(category as AnimalCategory?)
}
}

Picker("Diet", selection: $selectedDiet) {
ForEach(Animal.Diet.allCases, id: \.self) { diet in
Text(diet.rawValue).tag(diet)
}
}
}
}
}

The sample app takes this approach because it uses the autosave feature from SwiftData. The autosave feature automatically saves data changes made to model class instances, such as `animal`, instead of relying on the app to make explicit calls to the model context `save()` method. For more information about autosave, see `autosaveEnabled`.

Finally, to make the purpose of the editor clear to the person using it, `AnimalEditor` uses the `editorTitle` computed property to displays the title in the `principal` item section of the toolbar:

.toolbar {
ToolbarItem(placement: .principal) {
Text(editorTitle)
}
}

### Set default values

The `AnimalEditor` view declares its state variables with default values for a new animal, setting `name` to an empty string, `selectedDiet` to `herbivorous`, and leaving `selectedCategory` as `nil`. But the editor also supports editing an existing animal.

If someone edits an animal, the editor needs to show the values of the animal to edit, not the default values for the new animal. The view stores the animal to edit in the `animal` property. To show the current values of that animal, the editor applies the `onAppear(perform:)` modifier and copies the editable values from `animal` to the state variables:

.onAppear {
if let animal {
// Edit the incoming animal.
name = animal.name
selectedDiet = animal.diet
selectedCategory = animal.category
}
}

### Save the data changes

To allow a person to save the changes they made in the editor, the editor provides a Save button in the toolbar:

ToolbarItem(placement: .confirmationAction) {
Button("Save") {
withAnimation {
save()
dismiss()
}
}
}

When a person clicks the Save button, it calls the editor’s `save` method. If the person is editing an existing animal, `save` copies the values from the state variables to the instance of `Animal`. This directly updates the data that SwiftData manages, and because the app uses the autosave feature, SwiftData automatically saves the changes without calling the model context `save()` method.

private func save() {
if let animal {
// Edit the animal.
animal.name = name
animal.diet = selectedDiet
animal.category = selectedCategory
} else {
// Add an animal.
// ...
}
}

When adding a new animal, the `save` function creates a new `Animal` instance, initializing it with the name and diet from the state variables. Then it sets the category and inserts the animal into the model context by calling the model context `insert(_:)` method:

private func save() {
if let animal {
// Edit the animal.
// ...
} else {
// Add an animal.
let newAnimal = Animal(name: name, diet: selectedDiet)
newAnimal.category = selectedCategory
modelContext.insert(newAnimal)
}
}

After saving the data, the Save button’s action closes the editor by calling `dismiss`.

### Discard the data changes

To discard changes that someone made, the editor provides a Cancel button in the toolbar:

ToolbarItem(placement: .cancellationAction) {
Button("Cancel", role: .cancel) {
dismiss()
}
}

When a person clicks the Cancel button, the editor discards any changes made to the data by calling `dismiss` in the button’s action. This closes the editor without saving the changes.

## See Also

### Essentials

Preserving your app’s model data across launches

Describe your model classes to SwiftData using the framework’s macros, and store instances of those models so they exist beyond the app’s runtime.

Adopting SwiftData for a Core Data app

Persist data in your app intuitively with the Swift native persistence framework.

SwiftData updates

Learn about important changes to SwiftData.

Adopting inheritance in SwiftData

Add flexibility to your models using class inheritance.

---

# https://developer.apple.com/documentation/swiftdata/adopting-inheritance-in-swiftdata

- SwiftData
- Adopting inheritance in SwiftData

Article

# Adopting inheritance in SwiftData

Add flexibility to your models using class inheritance.

## Overview

SwiftData supports class inheritance, an object-oriented programming feature that enables you to expand the kinds of use cases your models can support by creating new subclasses that add properties and capabilities to an existing base class.

Like other Swift subclasses, SwiftData models can inherit the properties and capabilities of a parent or superclass. In SwiftData this allows you to add new properties and behaviors that extend the capabilities of your models by creating a hierarchical relationship between them that you can operating on using query, predicate, and history operations. This enables you to build in more flexibility into your app as your models become more specialized and able to serve more diverse use cases.

An example of such an app might one that tracks trips: both personal trips, such as family vacations, and business trips. At a high level, a trip might be captured in a very concise model, like the one shown here.

@Model LivingAccommodation { ... }

@Model class Trip {
@Attribute(.preserveValueOnDeletion)
var name: String
var destination: String

@Attribute(.preserveValueOnDeletion)
var startDate: Date

@Attribute(.preserveValueOnDeletion)
var endDate: Date

@Relationship(deleteRule: .cascade, inverse: \BucketListItem.trip)
var bucketList: [BucketListItem] = BucketListItem

@Relationship(deleteRule: .cascade, inverse: \LivingAccommodation.trip)
var livingAccommodation: LivingAccommodation?

var isBusinessTrip: Boolean = false
}

A name, a destination, start and end dates, living accommodations, and `true` or `false` values that indicate a business or personal trip: this is functional, but as the capabilities for a trip tracking app grow, it might expand to track more kinds of information, and this is where inheritance can provide more flexibility.

## Design for specialization

As described above, inheritance allows you to develop models that share fundamental properties but that diverge as use cases become more specialized. For example, a more expansive view of business and personal trips may include the addition of new elements depending upon the specific use case. The following table shows a few more elements that these trips this might record.

| Personal Trip | Business Trip |
| --- | --- |
| attractionsToVisit | expenseCode |
| familyMembers | businessMeals |
| frequentFlyerCodes | milageRate |
| venuePasses | milesDriven |
| | conferenceSessions |

Subclasses that build upon the base `Trip` model make use of its properties and any common behavior, but keep these new behaviors isolated. For example, a `PersonalTrip` doesn’t have to have a state or behavior for calculating the cumulative miles traveled in a reimbursement calculation: that’s more relevant to a `BusinessTrip`.

Given the outline of personal and business trip specialization above, you’d create model subclasses for SwiftData subclasses as you would in Swift, but with the addition of the `@Model` macro, to indicate the new class is a model to SwiftData. A refactoring of our trip classes into a parent (base) class and two subclasses could resemble these classes:

import SwiftData

@Model BucketListActivity { ... }

@Relationship(deleteRule: .cascade, inverse: \LivingAccommodation.trip)
var livingAccommodation: LivingAccommodation?
}

Here, an expanded `Trip` base class no longer uses the Boolean value that previously indicated the kind of trip. The following `BusinessTrip` and `PersonalTrip` subclasses describe additional properties and behaviors that could define these specialized trip types and create a hierarchical relationship between the parent and the subclasses.

@available(iOS 26, *)
@Model class BusinessTrip: Trip {
var purpose: String
var itinerary: MeetingItinerary
var expenseCode: String
var perDiemRate: Double
var mileageRate: Double

@Relationship(deleteRule: .cascade, inverse: \DailyMilageRecord.trip)
var milesDriven: [DailyMilageRecord]

@Relationship(deleteRule: .cascade, inverse: \BusinessMeal.trip)
var businessMeals: [BusinessMeal]

@Relationship(deleteRule: .cascade, inverse: \ConferenceSession.trip)
var sessionsAttended: [ConferenceSession]
}

The `PersonalTrip` subclass may have a very different set of properties, its design and use case shares very little with a business trip, beside the name, place, optional transportation, and duration, as shown here.

@Model Attraction { ... }
@Model FamilyMember { ... }

@available(iOS 26, *)
@Model class PersonalTrip: Trip {
enum Reason: String, CaseIterable, Codable, Identifiable {
case family
case reunion
case wellness
case unknown

var id: Self { self }
}

var reason: Reason
@Relationship(deleteRule: .cascade, inverse: \BucketListActivities.trip)
var bucketList: [BucketListActivity]
var attractionsToVisit: [Attraction]
var familyMembers: [FamilyMember]
}

## Determine whether inheritance is right for your use case

Inheritance is useful when defining class hierarchies where you need to specialize a model representation that derives from a common base. For example `Trip`, `PersonalTrip`, and `BusinessTrip` form a natural hierarchy: a business trip and a personal trip extend the basic concept of a “trip” and create, in the language of Object Oriented design, an “IS-A” relationship. A `BusinessTrip` IS-A `Trip`. and a `PersonalTrip` also IS-A `Trip`.

Avoid using inheritance in scenarios where the specialized subclass would center on common properties, such as a trip’s name, or starting or ending dates; subclassing at this level of granularity, the class hierarchy would contain many subdomains that only share a single property. In these cases if common properties need some kind of specialized behavior, protocol conformance is a better tool.

Avoid using inheritance if your querying model would depend on fetching all of the model data all the time and then filtering the results, — this is known as a _deep query_. It’s possible the specialization (here the difference between personal and business trips) is something that a Boolean type could represent as it did in the initial `Trip` model where a Boolean value differentiated the type of trip. Another method to keep models “flatter,” reduce the number of properties, and avoid inheritance is to add an enumeration type that has a value which captures the type of trip and it’s value, here the personal trip’s reason or the business trip’s per diem value instead of an `isBusinessTrip` Boolean property, as shown here:

enum Category: Codable {
case personal(Reason)​​​​​​​​​​​​
case business(perdiem: Double)​​​​​​​​​​​​
}

As your model’s and use cases expand, adding more properties may become impractical or difficult to maintain.

Conversely, if your app’s query strategy _only_ focuses on the specialization — specific properties that define a business trip or a personal trip and never on the properties of the base trip model — known as a _shallow query_ — then using two models might be a better approach, even though each individual model might contain some apparent duplication.

Lastly, If the query strategy for your app involves allowing a person to perform elements of both deep and shallow searches, in order find and return information from both a base and the subclasses, then inheritance may be a good fit for your app’s model and use case.

## Fetch and Query Data

Combining inheritance and customized predicates it’s possible to create any number of customized searching and filtering mechanisms that can select from any of the properties available in your parent or subclasses.

For example, to search for text in both `BusinessTrip` and `PersonalTrip` types, perform a deep search on properties using the base class `Trip`, as this the outline demonstrates:

struct TripListView: View {
@Environment(\.modelContext) private var modelContext
// All trips, in ascending order, by start date.
@Query(sort: \Trip.startDate, order: .forward)
var trips: [Trip]

init(searchText: String) {

searchText.isEmpty ? true : $0.name.localizedStandardContains(searchText) || $0.destination.localizedStandardContains(searchText)
}
// Filter the trips array using predicate, which searches the trip name and destination for the provided `searchText`.
_trips = Query(filter: searchPredicate, sort: \.startDate, order: .forward)
}

var body: some View {
/* View body contents */
}
}

Selecting trips based on type, or all trips is a similar predicate: this example uses a simple enumeration and a switch to indicate which kind of trips to select.

enum TripKind: String, CaseIterable {
case all = "All"
case personal = "Personal"
case business = "Business"
}

struct TripListView: View {
@Environment(\.modelContext) private var modelContext
/// All trips, in ascending order, by start date.
@Query(sort: \Trip.startDate, order: .forward)
var trips: [Trip]

// Create a predicate, selected by the provided enumeration
// case, that examines the object's class to determine if it's
// a `BusinessTrip`, `PersonalTrip`, or `Trip`.

switch tripKind.wrappedValue {
// Returns a `nil` predicate representing all trips.
case .all:
return nil
// Returns a predicate that matches on `PersonalTrip` objects.
case .personal:
return #Predicate { $0 is PersonalTrip }
// Returns a predicate that matches on `BusinessTrip` objects.
case .business:
return #Predicate { $0 is BusinessTrip }
}
}()

// Filter the trips array using predicate, which matches on trips of a specific class.
_trips = Query(filter: classPredicate, sort: \.startDate, order: .forward)
}

var body: some View {
// View body contents that displays the matching trips.
}
}

The following example demonstrates how to combine both of these predicates to search for text in the trip’s’ `name` and `destination` properties, as well as by trips or by type of trip, if specified:

struct TripListView: View {
@Environment(\.modelContext) private var modelContext
/// All trips, ordered by start date.
@Query(sort: \Trip.startDate, order: .forward)
var trips: [Trip]

// Create a predicate that examines the object's class to determine
// if it's a `BusinessType`, `Personal`, or `Trip` ("all trips").

// If there's search text, create a predicate than can search the trip's name and destination.

searchText.isEmpty ? true : $0.name.localizedStandardContains(searchText) || $0.destination.localizedStandardContains(searchText)
}

fullPredicate = #Predicate { classPredicate.evaluate($0) && searchPredicate.evaluate($0) }
} else {
fullPredicate = searchPredicate
}
// Filter trips on other `searchText` or trip type, or both.
_trips = Query(filter: fullPredicate, sort: \.startDate, order: .forward)
}

var body: some View {
// View body contents that displays the matching trips.
}
}

## See Also

### Essentials

Preserving your app’s model data across launches

Describe your model classes to SwiftData using the framework’s macros, and store instances of those models so they exist beyond the app’s runtime.

Adding and editing persistent data in your app

Create a data entry form for collecting and changing data managed by SwiftData.

Adopting SwiftData for a Core Data app

Persist data in your app intuitively with the Swift native persistence framework.

SwiftData updates

Learn about important changes to SwiftData.

---

# https://developer.apple.com/documentation/swiftdata/index(_:)-7d4z0

-7d4z0#app-main)

- SwiftData
- Index(\_:)

Macro

# Index(\_:)

Specifies the key-paths that SwiftData uses to create one or more indicies for the associated model, where each index is either binary or R-tree.

Swift 5.9+

@freestanding(declaration)

## See Also

### Model definition

`macro Model()`

Converts a Swift class into a stored model that’s managed by SwiftData.

`macro Attribute(Schema.Attribute.Option..., originalName: String?, hashModifier: String?)`

Specifies the custom behavior that SwiftData applies to the annotated property when managing the owning class.

Specifies the key-paths that SwiftData uses to enforce the uniqueness of model instances.

Specifies the key-paths that SwiftData uses to create one or more binary indices for the associated model.

Defining data relationships with enumerations and model classes

Create relationships for static and dynamic data stored in your app.

`macro Relationship(Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule, minimumModelCount: Int?, maximumModelCount: Int?, originalName: String?, inverse: AnyKeyPath?, hashModifier: String?)`

Specifies the options that SwiftData needs to manage the annotated property as a relationship between two models.

`macro Transient()`

Tells SwiftData not to persist the annotated property when managing the owning class.

---

# https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes

- SwiftData
- Defining data relationships with enumerations and model classes

Sample Code

# Defining data relationships with enumerations and model classes

Create relationships for static and dynamic data stored in your app.

Download

Xcode 15.0+

## Overview

There are two ways to define data relationships in your app: using enumerations and using the `Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)` macro in a model class. Which one to use depends on the unique circumstances of your app. This article explains how to apply both approaches to the sample SwiftUI app that persist data using SwiftData.

### Relate a model class to static data

Enumerations are a convenient way to form relationships between a model class and static data — data that the app defines and doesn’t change. To define the static data, create an enumeration and ensure it conforms to the `Codable` protocol. SwiftData requires this conformance to persist any data that is of the enumeration type. The following code, for example, declares a `Codable` conforming enumeration that specify the animal type based on their diets:

extension Animal {
enum Diet: String, CaseIterable, Codable {
case herbivorous = "Herbivore"
case carnivorous = "Carnivore"
case omnivorous = "Omnivore"
}
}

The `Animal` model class declares the property `diet` as a type of `Diet`. Because this property is non-optional, its value must be set to one of the `Diet` cases: `herbivore`, `carnivore`, and `ominvore`.

@Model
final class Animal {
var name: String
var diet: Diet
var category: AnimalCategory?

init(name: String, diet: Diet) {
self.name = name
self.diet = diet
}
}

A person using the sample app can set the diet of an animal by choosing one of the available `Diet` cases from a `Picker`; for example:

Picker("Diet", selection: $selectedDiet) {
ForEach(Animal.Diet.allCases, id: \.self) { diet in
Text(diet.rawValue).tag(diet)
}
}

To learn more about how the sample app saves data changes, see Adding and editing persistent data in your app.

### Relate a model class to dynamic data

If the related data is dynamic and unknown to the app — data that comes from an external source such as someone using the app or a remote server — then form a relationship between two model classes instead of a class and enumeration. For instance, the dynamic data in the sample app includes animals and animal categories. An animal can belong to no more than one animal category, and a category can contain zero, one, or more animals.

To declare this relationship, the `AnimalCategory` class defines the property `animals`, which represents the animals contained in the category. The class also applies the `Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)` macro to the `animals` property. This macro defines the relationship between the `AnimalCategory` and `Animal` model classes.

@Model
final class AnimalCategory {
@Attribute(.unique) var name: String
// `.cascade` tells SwiftData to delete all animals contained in the
// category when deleting it.
@Relationship(deleteRule: .cascade, inverse: \Animal.category)
var animals = Animal

init(name: String) {
self.name = name
}
}

Set the parameter values of this macro to configure the relationship. For example, the `deleteRule` parameter specifies how SwiftData handles related data during delete operations. The `inverse` parameter is a key path to the store property, `category`, declared in the related model class, `Animal`. The inverse parameter forms the relationship between the two classes, `AnimalCategory` and `Animal`, and the `category` property declared in `Animal` provides a reference to an animal category.

### Set a relationship’s delete rule

The `deleteRule` parameter specifies how SwiftData handles delete operations with regards to the related data. The `Schema.Relationship.DeleteRule.cascade` delete rule tells SwiftData to delete all related data when deleting the primary object. For example, deleting an `AnimalCategory` in the sample app causes SwiftData to also delete all animals contained in that category.

@Relationship(deleteRule: .cascade, inverse: \Animal.category)
var animals = Animal

If you don’t want to delete the animals within a category, you can use the `Schema.Relationship.DeleteRule.nullify` delete rule. This rule tells SwiftData to set the animal’s `category` property to `nil` for each animal contained in the animal category when deleting the category. Because the default value for the `deleteRule` parameter is `nullify`, you can create the relationship without explicitly specifying the delete rule, like so:

@Relationship(inverse: \Animal.category)
var animals = Animal

For a complete list of delete rules, see `Schema.Relationship.DeleteRule`.

### Create a model container

Whether your data model includes relationships, you must always create a model container for your app when using SwiftData. The sample app creates a model container using the `modelContainer(for:inMemory:isAutosaveEnabled:isUndoEnabled:onSetup:)` modifier, passing in the model type `AnimalCategory.self`:

@main
struct SwiftDataAnimalsApp: App {
var body: some Scene {
WindowGroup() {
ContentView()
}
.modelContainer(for: AnimalCategory.self)
}
}

SwiftData uses the model type to construct the schema that determines the structure of the persistent storage area. The schema also includes all related types that form the object graph of the provided model type. For instance, `AnimalCategory` is a root model type of an object graph. `AnimalCategory` contains a relationship to the model type `Animal`, which means that the schema includes `Animal` along with `AnimalCategory`. If `Animal` had a relationship to another model type, the schema would also include that type.

If your app defines multiple root model types, use the

`modelContainer(for:inMemory:isAutosaveEnabled:isUndoEnabled:onSetup:)` modifier, passing in an array that contains each root model type used in your app.

## See Also

### Model definition

`macro Model()`

Converts a Swift class into a stored model that’s managed by SwiftData.

`macro Attribute(Schema.Attribute.Option..., originalName: String?, hashModifier: String?)`

Specifies the custom behavior that SwiftData applies to the annotated property when managing the owning class.

Specifies the key-paths that SwiftData uses to enforce the uniqueness of model instances.

Specifies the key-paths that SwiftData uses to create one or more binary indices for the associated model.

Specifies the key-paths that SwiftData uses to create one or more indicies for the associated model, where each index is either binary or R-tree.

`macro Relationship(Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule, minimumModelCount: Int?, maximumModelCount: Int?, originalName: String?, inverse: AnyKeyPath?, hashModifier: String?)`

Specifies the options that SwiftData needs to manage the annotated property as a relationship between two models.

`macro Transient()`

Tells SwiftData not to persist the annotated property when managing the owning class.

---

# https://developer.apple.com/documentation/swiftdata/transient()

#app-main)

- SwiftData
- Transient()

Macro

# Transient()

Tells SwiftData not to persist the annotated property when managing the owning class.

Swift 5.9+

@attached(peer)
macro Transient()

## Mentioned in

Preserving your app’s model data across launches

## Overview

If your model class has one or more stored properties that you want to omit from writes to the persistent storage, annotate each of those properties with the `@Transient` macro.

@Model
class RemoteImage {
var sourceURL: URL
var data: Data

@Transient
var isDownloading = false

init(sourceURL: URL, data: Data = Data(), isDownloading: Bool) {
self.sourceURL = sourceURL
self.data = data
self.isDownloading = isDownloading
}
}

Unless the type of the annotated property is an optional, the `@Transient` macro requires you to provide a default value. This constraint enables SwiftData to successfully materialize instances of the enclosing model class when running fetches.

## See Also

### Model definition

`macro Model()`

Converts a Swift class into a stored model that’s managed by SwiftData.

`macro Attribute(Schema.Attribute.Option..., originalName: String?, hashModifier: String?)`

Specifies the custom behavior that SwiftData applies to the annotated property when managing the owning class.

Specifies the key-paths that SwiftData uses to enforce the uniqueness of model instances.

Specifies the key-paths that SwiftData uses to create one or more binary indices for the associated model.

Specifies the key-paths that SwiftData uses to create one or more indicies for the associated model, where each index is either binary or R-tree.

Defining data relationships with enumerations and model classes

Create relationships for static and dynamic data stored in your app.

`macro Relationship(Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule, minimumModelCount: Int?, maximumModelCount: Int?, originalName: String?, inverse: AnyKeyPath?, hashModifier: String?)`

Specifies the options that SwiftData needs to manage the annotated property as a relationship between two models.

---

# https://developer.apple.com/documentation/swiftdata/modelcontainer

- SwiftData
- ModelContainer

Class

# ModelContainer

An object that manages an app’s schema and model storage configuration.

Swift 5.9+

class ModelContainer

## Mentioned in

Syncing model data across a person’s devices

Reverting data changes using the undo manager

## Overview

A model container mediates between its associated model contexts and your app’s underlying persistent storage. The container manages all aspects of that storage and ensures it remains in a consistent and usable state. Whenever you run a fetch or call a context’s `save()` method, the container performs the actual read or write of the underlying data using information from the schema you provide. This helps safeguard an app’s resources and ensures those operations happen only in an efficient and coordinated manner. Additionally, if your app’s entitlements include CloudKit, the container automatically handles syncing the persisted storage across devices. For more information about syncing model data, see Syncing model data across a person’s devices.

As your app’s schema evolves, the container performs automatic migrations of the persisted model data so it remains consistent with the app’s model classes. If the aggregate changes between two versions of your schema exceed the capabilities of automatic migrations, provide the container with a `SchemaMigrationPlan` to participate in those migrations and help ensure they complete successfully.

By default, a model container makes a number of assumptions about how it configures an app’s persistent storage. If you need to customize this behavior, provide the container with one or more instances of `ModelConfiguration`. For example, you may want use a particular app group container or specify that the storage is ephemeral and should exist only in memory.

An app that uses SwiftData requires at least one model container. You create a container using one of the class’s initializers or the corresponding SwiftUI view modifier. Using the view modifier ensures all windows in the modified window group, or all child views of the modified view, access the same model container. Additionally, the view modifier makes an associated model context available in the SwiftUI environment, which the `Query()` macro depends on.

@main
struct RecipesApp: App {
var body: some Scene {
WindowGroup {
RecipesList()
}
.modelContainer(for: Recipe.self)
}
}

struct RecipesList: View {
@Query private var recipes: [Recipe]

var body: some View {
List(recipes) { RecipeRowView($0) }
}
}

## Topics

### Creating a model container

[`init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: [ModelConfiguration]) throws`](https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:migrationplan:configurations:)-1czix)

Creates a model container using the specified schema, migration plan, and configurations.

`convenience init(for: any PersistentModel.Type..., migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified model types, migration plan, and zero or more configurations.

`convenience init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified schema, migration plan, and zero or more configurations.

`protocol PersistentModel`

An interface that enables SwiftData to manage a Swift class as a stored model.

`struct ModelConfiguration`

A type that describes the configuration of an app’s schema or specific group of models.

`class Schema`

An object that maps model classes to data in the model store, and helps with the migration of that data between releases.

`protocol SchemaMigrationPlan`

An interface for describing the evolution of a schema and how to migrate between specific versions.

### Managing schema and configuration details

`let schema: Schema`

The schema that maps your app’s model classes to the associated data in the app’s persistent storage.

The configurations that describe how to manage the persisted data for specific groups of models.

`let migrationPlan: (any SchemaMigrationPlan.Type)?`

The plan that describes the evolution of your app’s schema and how to migrate between specific versions.

### Accessing the context

`var mainContext: ModelContext`

A model context that’s bound to app’s main actor.

### Deleting the container

`func deleteAllData()`

Removes all persisted model data from the app’s persistent storage.

### Comparing model containers

Returns a Boolean value indicating whether two values are equal.

### Initializers

`convenience init(for: any PersistentModel.Type..., configurations: any DataStoreConfiguration...) throws`

[`init(for: Schema, configurations: [any DataStoreConfiguration]) throws`](https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:configurations:)-93ifi)

### Instance Methods

`func erase() throws`

## Relationships

### Conforms To

- `Equatable`
- `Sendable`
- `SendableMetatype`

## See Also

### Model life cycle

`class ModelContext`

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

`struct HistoryDescriptor`

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

---

# https://developer.apple.com/documentation/swiftdata/fetching-and-filtering-time-based-model-changes

- SwiftData
- Fetching and filtering time-based model changes

Article

# Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

## Overview

As people interact with your app, the app’s persisted model data may change over time. For example, a person (or process) may create, update, or delete model instances. When the app fetches data from the data store, those results represent only the current state of that model data; there’s no straightforward way to determine if there’s been any changes to that data since the last fetch.

SwiftData History enables your app to track changes in its data store over time. The data store organizes changes as a series of chronological transactions, where each transaction contains information about one or more persisted changes. Your app can fetch these transactions and react accordingly. For example, your app may need to determine changes made by another process such as a Widget or App Intent and reflect those changes in its user interface.

To use SwiftData History in your app, create a history descriptor and use a model context to fetch the corresponding chronological transactions. After the fetch completes, determine which of those fetched transactions relate to the current view or task and process them accordingly. After you finish processing them, delete the transactions from the store to reclaim the disk space.

## Fetch a store’s change transactions

Transactions group together one or more changes that occur on a specific boundary — such as when a model context writes pending changes to the store — and are identifiable by their associated history token. SwiftData stores transactions in the order they occur, and a model context fetches them in that same order. The group of changes that a transaction contains (inserts, updates, deletes) are also ordered chronologically.

Using a model context, you can fetch all transactions from the persistent store, or just a subset by specifying a history token, an author, or both. Tokens are opaque objects that conform to the `Comparable` and `Codable` protocols, enabling you to store the most recent token on-disk and use it in the next fetch to receive only newer changes. An author is a short string that your app uses to identify the origin of a transaction, which you specify on the model context that writes those changes to the store.

For example, you may want to fetch all new transactions that originate from your app’s widget.

do {
// Decode the given token data.
let token = try JSONDecoder().decode(History.DefaultToken.self, from: tokenData)
// Create a history descriptor and specify the predicate.

descriptor.predicate = #Predicate {

}
// Fetch the matching history transactions.
let context = ModelContext(modelContainer)
let txns = try context.fetchHistory(descriptor)
return .success(txns)
} catch {
return .failure(error)
}
}

After processing the fetched transactions, make sure that you write the most recent transaction’s token to disk so you can use it in the next fetch.

## Identify relevant model changes

As transactions represent points in time, they’re heterogenous — a single transaction can (and often will) contain changes for several different model types. Because of this, transactions aren’t bound to a specific model type. When you fetch them from a data store, the results will likely contain transactions, and changes within those transactions, that are unrelated to the current view or task. Filter each transaction’s changes and identify only those that are relevant.

The following example shows how you might identify trips with updated flight times:

let context = ModelContext(modelContainer)

for txn in transactions {
// Filter out any change that isn't an update.

// Proceed only when there's a single change, and that change
// is to the `flightTime` attribute.
guard change.updatedAttributes.count == 1,
change.updatedAttributes.contains(\.flightTime)
else { continue }
// Use the model ID from the change to fetch the actual model.
let changedModelID = change.changedModelID

$0.persistentModelID == changedModelID
})
if let trip = try? taskContext.fetch(fetchDescriptor).first {
updatedTrips.insert(trip)
}
}
}

## Preserve important attributes of deleted models

After deleting a model from the data store, its values are gone with no way to recover them. In most situations, this is the preferred behavior. However, there may be occasions where your app needs to retain one or more attribute values from a deleted model. For example, using a model’s `persistentModelID` as a means of identifying that model is only relevant within the scope of the local data store, and a different attribute may provide a stable identity across different devices and services. By retaining that attribute’s value, you’re able to reliably identify the deleted model after it’s gone.

To retain a value, use the `Attribute(_:originalName:hashModifier:)` macro and specify the `preserveValueOnDeletion` option:

@Model
final class Trip {
@Attribute(.preserveValueOnDeletion)
var airlineBookingRef: String
// ...
}

Then, when processing a transaction’s changes, use the `tombstone` property to retrieve the preserved value. `History/Tombstone` is a generic sequence type that lets you iterate over the preserved values, or access a specific value directly using the corresponding model key path.

bookingRef = deletion.tombstone[\.airlineBookingRef]
}

## Delete stale change transactions

SwiftData writes transactions to the data store alongside the model data, and as such, transactions require additional disk space. To make sure the store doesn’t consume more space than necessary, determine a suitable clean-up strategy to remove stale transactions when your app no longer needs them.

Similar to fetching, use a model context to delete transactions and provide a predicate to narrow the scope. For example, you may want to delete all transactions that occur before a given token:

do {
// Create a history descriptor and specify the predicate.

descriptor.predicate = #Predicate {
$0.token < token
}
// Delete the matching history transactions.
let context = ModelContext(modelContainer)
try context.deleteHistory(descriptor)
return .success
} catch {
return .failure(error)
}
}

## See Also

### Model life cycle

`class ModelContainer`

An object that manages an app’s schema and model storage configuration.

`class ModelContext`

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

`struct HistoryDescriptor`

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Reverting data changes using the undo manager

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

Syncing model data across a person’s devices

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

---

# https://developer.apple.com/documentation/swiftdata/historydescriptor

- SwiftData
- HistoryDescriptor

Structure

# HistoryDescriptor

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Swift 5.9+

## Topics

### Creating a descriptor

Initializes a new history descriptor with the provided predicate.

Initializes a new history descriptor with the provided predicate and sort descriptor.

### Getting the descriptor configuration

`var fetchLimit: UInt64`

The maximum number of transactions to retrieve from the model store’s history.

The predicate used to initialize the history descriptor.

The sort descriptor to use to sort the returned history data.

## See Also

### Model life cycle

`class ModelContainer`

An object that manages an app’s schema and model storage configuration.

`class ModelContext`

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Reverting data changes using the undo manager

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

Syncing model data across a person’s devices

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

---

# https://developer.apple.com/documentation/swiftdata/deleting-persistent-data-from-your-app

- SwiftData
- Deleting persistent data from your app

Sample Code

# Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Download

Xcode 15.0+

## Overview

Data-driven apps typically provide a way for a person to delete data, and this sample is no exception. It shows three ways to remove data stored in a SwiftData model container:

- Swiping to delete

- Deleting with confirmation

- Deleting all

## Swipe to delete

The sample app shows a list of animals. A person using the app can delete an animal using a swipe gesture. For example, the following code adds the swipe-to-delete option to the `AnimalList` view by applying the `onDelete(perform:)` modifier to `ForEach`:

private struct AnimalList: View {
@Environment(NavigationContext.self) private var navigationContext
@Environment(\.modelContext) private var modelContext
@Query(sort: \Animal.name) private var animals: [Animal]

var body: some View {
@Bindable var navigationContext = navigationContext
List(selection: $navigationContext.selectedAnimal) {
ForEach(animals) { animal in
NavigationLink(animal.name, value: animal)
}
.onDelete(perform: removeAnimals)
}
}
}

The `onDelete(perform:)` modifier in the previous code calls the custom method `removeAnimals` to remove one or more animals from the list. This method receives an `IndexSet` which identifies the animals to delete. The method then iterates through the index set, deleting each animal using the `ModelContext` method `delete(_:)`.

private func removeAnimals(at indexSet: IndexSet) {
for index in indexSet {
modelContext.delete(animals[index])
}
}

However, it’s possible for a person using this sample to delete the selected animal, so the `removeAnimals` method needs to unselect the animal before deleting it. The updated version of `removeAnimals` uses the `persistentModelID` to determine whether the animal to delete is also the selected animal. If it is, the method sets the selected animal to `nil`.

private func removeAnimals(at indexSet: IndexSet) {
for index in indexSet {
let animalToDelete = animals[index]
if navigationContext.selectedAnimal?.persistentModelID == animalToDelete.persistentModelID {
navigationContext.selectedAnimal = nil
}
modelContext.delete(animalToDelete)
}
}

The sample uses the SwiftData autosave feature, which is enabled by default when creating a `ModelContainer` using the `modelContainer(for:inMemory:isAutosaveEnabled:isUndoEnabled:onSetup:)` modifier. If this feature is disabled, the `removeAnimals` method needs to explicitly save the change by calling the `ModelContext` method `save()`; for example:

private func removeAnimals(at indexSet: IndexSet) {
do {
for index in indexSet {
let animalToDelete = animals[index]
if navigationContext.selectedAnimal?.persistentModelID == animalToDelete.persistentModelID {
navigationContext.selectedAnimal = nil
}
modelContext.delete(animalToDelete)
}
try modelContext.save()
} catch {
// Handle error.
}
}

## Delete with confirmation

The sample app also lets a person delete the selected animal by clicking the Trash button that `AnimalDetailView` displays in its toolbar.

struct AnimalDetailView: View {
var animal: Animal?
@State private var isDeleting = false
@Environment(\.modelContext) private var modelContext
@Environment(NavigationContext.self) private var navigationContext

var body: some View {
if let animal {
AnimalDetailContentView(animal: animal)
.navigationTitle("\(animal.name)")
.toolbar {
Button { isDeleting = true } label: {
Label("Delete \(animal.name)", systemImage: "trash")
.help("Delete the animal")
}
}
} else {
ContentUnavailableView("Select an animal", systemImage: "pawprint")
}
}
}

The action for the button set the state variable `isDeleting` to `true`, which displays the delete confirmation alert described in the following code:

.alert("Delete \(animal.name)?", isPresented: $isDeleting) {
Button("Yes, delete \(animal.name)", role: .destructive) {
delete(animal)
}
}

After confirming the delete request, the action for the confirmation button calls the custom `delete` method. This method sets the selected animal to `nil`, then deletes the animal from the model context by calling the `delete(_:)` method.

private func delete(_ animal: Animal) {
navigationContext.selectedAnimal = nil
modelContext.delete(animal)
}

If the SwiftData autosave feature was disabled, the `delete` method would need to explicitly save the change by calling the `ModelContext` method `save()`; for example:

private func delete(_ animal: Animal) {
do {
navigationContext.selectedAnimal = nil
modelContext.delete(animal)
try modelContext.save()
} catch {
// Handle error.
}
}

## Delete all

Deleting all items of a particular model type is less common in data driven apps, but there may be times when having this option is helpful. For example, the sample apps lets a person reload sample data that comes with the app. Reloading the sample data deletes all animal categories and animals from persistent storage.

To delete all items of a particular model type, use the `ModelContext` method `delete(model:where:includeSubclasses:)`. For example, the following code deletes all animal categories before reloading the sample data:

static func reloadSampleData(modelContext: ModelContext) {
do {
try modelContext.delete(model: AnimalCategory.self)
insertSampleData(modelContext: modelContext)
} catch {
fatalError(error.localizedDescription)
}
}

When deleting all animal categories, SwiftData also deletes all animals within those categories. SwiftData knows to perform this cascading delete because the relationship between `AnimalCategory` and `Animal` uses the `Schema.Relationship.DeleteRule.cascade` delete rule. (For a complete list of delete rules, see `Schema.Relationship.DeleteRule`.)

import SwiftData

@Model
final class AnimalCategory {
@Attribute(.unique) var name: String
// `.cascade` tells SwiftData to delete all animals contained in the
// category when deleting it.
@Relationship(deleteRule: .cascade, inverse: \Animal.category)
var animals = Animal

init(name: String) {
self.name = name
}
}

To delete all persistent data from your app and not just data of a certain model type, use the `ModelContainer` method `deleteAllData()`.

## See Also

### Model life cycle

`class ModelContainer`

An object that manages an app’s schema and model storage configuration.

`class ModelContext`

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

`struct HistoryDescriptor`

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Reverting data changes using the undo manager

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

Syncing model data across a person’s devices

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

---

# https://developer.apple.com/documentation/swiftdata/reverting-data-changes-using-the-undo-manager

- SwiftData
- Reverting data changes using the undo manager

Article

# Reverting data changes using the undo manager

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

## Overview

People who interact with apps to change data typically expect the app to provide a way to revert changes that they no longer wish to make. To provide this _undo_ support, apps can use `UndoManager`, which can:

- Record operations that a person performs while using the app

- Provide undo capability to revert the last operation

- Provide redo capability to reapply the last reverted operation

If your app uses SwiftData, it can automatically register data changes with the undo manager. No need for you to add more code to your app that records those changes. Instead, just enable undo in SwiftData.

### Enable undo in SwiftData

Using SwiftData to store data, you can enable undo support for data changes by setting the `isUndoEnabled` parameter to `true` when applying the `modelContainer(for:inMemory:isAutosaveEnabled:isUndoEnabled:onSetup:)` modifier to a scene or view in your SwiftUI app:

@main
struct SwiftDataAnimalsApp: App {
var body: some Scene {
WindowGroup() {
ContentView()
}
.modelContainer(for: AnimalCategory.self, isUndoEnabled: true)
}
}

Other than enabling undo in SwiftData, you don’t need to write any additional code to manage undo operations for data changes. Instead, SwiftData automatically registers data change operations with the undo manager each time SwiftData saves those changes to the main context. And if your app uses `DocumentGroup` to manage data storage, undo and redo in SwiftData is automatically enabled.

## See Also

### Model life cycle

`class ModelContainer`

An object that manages an app’s schema and model storage configuration.

`class ModelContext`

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

`struct HistoryDescriptor`

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Syncing model data across a person’s devices

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

---

# https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices

- SwiftData
- Syncing model data across a person’s devices

Article

# Syncing model data across a person’s devices

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

## Overview

People who use your app to create content expect that content to be available on all of their devices. SwiftData makes it possible to synchronize content by abstracting away the associated complexities. To adopt the framework’s automatic sync functionality, add two Xcode capabilities to your app. The system operates with a set of predictable behaviors, such as using your app’s `Entitlements.plist` file to infer the CloudKit configuration.

SwiftData uses the `NSPersistentCloudKitContainer` class from Core Data to handle CloudKit synchronization. For more information about how your models become instances of `CKRecord`, see Reading CloudKit Records for Core Data.

### Add the iCloud and Background Modes capabilities

SwiftData requires two separate capabilities to perform automatic iCloud sync: the iCloud capability, which lets you configure CloudKit, and the Background Modes capability, which lets your app receive remote notifications from CloudKit that contain information about new changes on the server.

To add the iCloud and Background Modes capabilities:

1. Follow the steps in Configuring iCloud services to add the iCloud capability to your Xcode project, enable CloudKit, and create or choose an existing _container_ — an object that CloudKit uses to isolate your app’s databases on the iCloud servers and manage their access and operations.

2. Follow the steps in Configuring background execution modes to add the Background Modes capability, enabling the Remote notifications option. The system delivers remote notifications silently to your app, allowing SwiftData to process the changes they describe and keep your local model data in sync with the iCloud servers.

### Define a CloudKit compatible schema

A model layer described using macros in SwiftData will, in many cases, generate a schema already compatible with CloudKit. However, the SwiftData framework does include a small number of features that CloudKit doesn’t support natively, such as unique constraints and nonoptional relationships. It’s important you consider these limitations as you design your app’s model layer (or adapt an existing one) to ensure it remains compatible with CloudKit.

| SwiftData macro | CloudKit schema limitation |
| --- | --- |
| `@Attribute` | The framework synchronizes changes concurrently and at opportune times, which means CloudKit is unable to enforce the `unique` property option. |
| `@Relationship` | The iCloud servers don’t guarantee atomic processing of relationship changes, so CloudKit requires all relationships to be optional. SwiftData automatically sets the inverse of a relationship if it can reliably infer that inverse from your schema. Otherwise, explicitly set the inverse before saving because CloudKit processes changes in an indeterminate order. The framework doesn’t immediately synchronize changes, meaning CloudKit is unable to support the `Schema.Relationship.DeleteRule.deny` delete rule. |

You manually initialize your app’s CloudKit schema during development — as the following section describes — but you need to promote that schema to production before releasing your app. CloudKit schemas are additive only, which means you’re unable to delete model types or change existing model attributes after you promote a schema to production.

### Initialize the CloudKit development schema

After you define a model layer that’s compatible with CloudKit, use the existing integration from Core Data with CloudKit to initialize a copy of that model layer on the iCloud servers. For example, you might do this during app launch by adding the necessary code to the `init()` function of the type in your app that adopts the `App` protocol from SwiftUI.

Follow these steps to ensure proper CloudKit schema initialization:

1. Create an instance of `ModelConfiguration`, which provides some basic information about the app’s SwiftData stack.

2. Use the configuration’s `url` property to create an instance of `NSPersistentStoreDescription`, enabling SwiftData and Core Data to reference the same store on disk.

3. Configure the store description with your app’s CloudKit container identifier.

4. Request Core Data load the store synchronously, to guarantee that the load finishes before you attempt to initialize the CloudKit schema.

5. Create a managed object model that contains the same model types as the `ModelConfiguration` instance.

6. Use `NSPersistentCloudKitContainer` to load the store from the description and to initialize the CloudKit schema.

7. Unload the persistent store before creating an instance of `ModelContainer` to avoid both frameworks attempting to sync data to CloudKit.

let config = ModelConfiguration()

do {
#if DEBUG
// Use an autorelease pool to make sure Swift deallocates the persistent
// container before setting up the SwiftData stack.
try autoreleasepool {
let desc = NSPersistentStoreDescription(url: config.url)
let opts = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.example.Trips")
desc.cloudKitContainerOptions = opts
// Load the store synchronously so it completes before initializing the
// CloudKit schema.
desc.shouldAddStoreAsynchronously = false
if let mom = NSManagedObjectModel.makeManagedObjectModel(for: [Trip.self, Accommodation.self]) {
let container = NSPersistentCloudKitContainer(name: "Trips", managedObjectModel: mom)
container.persistentStoreDescriptions = [desc]
container.loadPersistentStores {_, err in
if let err {
fatalError(err.localizedDescription)
}
}
// Initialize the CloudKit schema after the store finishes loading.
try container.initializeCloudKitSchema()
// Remove and unload the store from the persistent container.
if let store = container.persistentStoreCoordinator.persistentStores.first {
try container.persistentStoreCoordinator.remove(store)
}
}
}
#endif
modelContainer = try ModelContainer(for: Trip.self, Accommodation.self,
configurations: config)
} catch {
fatalError(error.localizedDescription)
}

To ensure that schema initialization runs only in nonproduction builds, wrap your code with the `#if` compiler directive and specify the `DEBUG` compiler flag.

Go to the CloudKit Console to verify the initialized schema. If you’re unable to see your schema’s record types or data, you may need to enable querying support. For more information, see Inspecting and Editing an iCloud Container’s Schema.

### Configure SwiftData to use an existing CloudKit container

By default, SwiftData inspects your app’s `Entitlements.plist` file to determine which CloudKit container to use, and selects the first identifier it finds in that file. If your app uses multiple CloudKit containers, you may need to configure SwiftData to use a specific identifier instead of relying on the default behavior.

To opt out of automatic container discovery in SwiftData, create an instance of `ModelConfiguration` and use the initializer’s `cloudKitDatabase` parameter to specify your preferred identifier:

let config = ModelConfiguration(cloudKitDatabase: .private("iCloud.com.example.Trips"))
let modelContainer = try ModelContainer(for: Trip.self, Accommodation.self,
configurations: config)

### Disable automatic sync in apps already using CloudKit

SwiftData uses CloudKit to provide automatic iCloud sync and therefore requires the same Xcode-managed capabilities as those found in traditional CloudKit apps. This sharing of capabilities may lead to issues in apps already using CloudKit, because SwiftData assumes the presence of those capabilities as an indication that it handles sync. For example, automatic sync isn’t possible if there are incompatibilities between a SwiftData schema and an existing CloudKit schema.

In such scenarios, opt out of automatic iCloud sync by creating an instance of `ModelConfiguration` and explicitly pass `none` for the `cloudKitDatabase` parameter:

let config = ModelConfiguration(cloudKitDatabase: .none)
let modelContainer = try ModelContainer(for: Trip.self, Accommodation.self,
configurations: config)

Specifying `none` overrides any automatically discovered identifiers and disables SwiftData’s automatic iCloud sync.

## See Also

### Model life cycle

`class ModelContainer`

An object that manages an app’s schema and model storage configuration.

`class ModelContext`

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

`struct HistoryDescriptor`

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Reverting data changes using the undo manager

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

---

# https://developer.apple.com/documentation/swiftdata/concurrencysupport

Collection

- SwiftData
- Concurrency support

API Collection

# Concurrency support

Types you use to access model attributes and perform storage-related tasks in a safe and isolated way.

## Topics

### Model actors

`macro ModelActor()`

Converts a Swift actor into a model actor by generating boilerplate code that fulfills the requirements of the associated protocol.

`protocol ModelActor`

An interface for providing mutually-exclusive access to the attributes of a conforming model.

### Model executors

`class DefaultSerialModelExecutor`

An object that safely performs storage-related tasks using an isolated model context.

`protocol SerialModelExecutor`

An interface for performing serial storage-related tasks using an isolated model context.

`protocol ModelExecutor`

An interface for performing storage-related tasks using an isolated model context.

## See Also

### Model life cycle

`class ModelContainer`

An object that manages an app’s schema and model storage configuration.

`class ModelContext`

An object that enables you to fetch, insert, and delete models, and save any changes to disk.

Fetching and filtering time-based model changes

Track all inserts, updates, and deletes that occur in a data store and process them as a series of chronological transactions.

`struct HistoryDescriptor`

A type that describes the criteria, and, optionally, sort order, to use when fetching history data

Deleting persistent data from your app

Explore different ways to use SwiftData to delete persistent data.

Reverting data changes using the undo manager

Automatically record data change operations that people perform in your SwiftUI app, and let them undo and redo those changes.

Syncing model data across a person’s devices

Add the required capabilities and define a compatible schema to enable SwiftData to automatically sync your app’s model data using iCloud.

---

# https://developer.apple.com/documentation/swiftdata/filtering-and-sorting-persistent-data

- SwiftData
- Filtering and sorting persistent data

Sample Code

# Filtering and sorting persistent data

Manage data store presentation using predicates and dynamic queries.

Download

Xcode 15.0+

## Overview

This sample app displays a list of earthquakes, showing the time, location, and size of each earthquake. To help people visualize the list, the app also pinpoints each earthquake on a map. You can select an earthquake in the list to highlight it on the map.

The app uses SwiftData to store and manage the earthquake data, and relies on dynamic queries to present the data in different ways. For example, people can select which day’s earthquakes to display, sort the earthquakes by magnitude or time in forward or reverse order, and filter by location name.

### Read the entire collection with a simple query

The app’s `ContentView` fetches a complete list of earthquakes by applying the `Query` macro to its `quakes` property:

@Query private var quakes: [Quake]

The query macro injects code that keeps the array of earthquake instances synchronized with items in the data store. The view uses this list of earthquakes to configure the navigation bar based on the selected earthquake. For example, it sets the title and subtitle in macOS:

.navigationTitle(quakes[selectedId]?.location.name ?? "Earthquakes")
.navigationSubtitle(quakes[selectedId]?.fullDate ?? "")

The above code relies on a subscript method that the app defines in an extension of `Array`:

extension Array where Element: Quake {

first { $0.id == id }
}
}

The subscript definition relies on the fact that model objects — types attributed with the `Model()` macro, like `Quake` — automatically conform to the `Identifiable` protocol, which means that each earthquake instance has a unique `id` parameter. When someone selects an earthquake in the list or map view, the app sets `selectedId` to the selected earthquake’s identifier.

### Add a sort parameter to order data

The map view draws circles to represent quakes at particular locations, using a size for the circle that corresponds to the earthquake’s magnitude. To keep the circles visible when several overlap, `MapView` sorts its query by magnitude so that the map draws larger circles behind smaller ones.

It introduces the sorting by adding parameters to the query macro:

@Query(sort: \Quake.magnitude, order: .reverse)
private var quakes: [Quake]

The output of this query drives the generation of the map content builder’s `QuakeMarker` instances, and always appears in the desired order:

Map(selection: $selectedIdMap) {
ForEach(quakes) { quake in
QuakeMarker(
quake: quake,
selected: quake.id == selectedId)
}
}

### Define a filter using a predicate

To ensure that the app’s interface remains approachable, the app limits how many earthquakes it displays based on:

- **A date** — To avoid overwhelming the map with too many markers, the app displays only one day’s worth of earthquakes at a time. People can choose which day to view.

- **A location name** — To enable people to focus on specific earthquakes, people can enter text in a search field that the app matches against earthquake location names.

To implement this filtering, the app defines a static method that returns a `Predicate` that takes into account both a search date and search text:

static func predicate(
searchText: String,
searchDate: Date

let calendar = Calendar.autoupdatingCurrent
let start = calendar.startOfDay(for: searchDate)
let end = calendar.date(byAdding: .init(day: 1), to: start) ?? start

(searchText.isEmpty || quake.location.name.contains(searchText))
&&

}
}

The app applies this predicate to the queries it creates dynamically, as the next section describes. By defining the predicate once in a central location, queries in multiple views can use it. This makes it easy to synchronize related views, like the list and map views, when the views have distinct queries.

### Update a query dynamically

When someone selects a new date or changes the search text, the app needs to update the query to match. The map view achieves this by providing an initializer with `searchDate` and `searchText` inputs, and rebuilding the stored query using those values:

init(

searchDate: Date = .now,
searchText: String = ""
) {
_selectedId = selectedId
_selectedIdMap = selectedIdMap

_quakes = Query(
filter: Quake.predicate(
searchText: searchText,
searchDate: searchDate),
sort: \.magnitude,
order: .reverse
)
}

Because these values are inputs to the view’s initializer, SwiftUI reevaluates the initializer to produce a new query whenever either value changes. This in turn updates the appearance of the view.

The earthquake list view does something similar, although in this case it takes sort configuration inputs as well:

searchText: String = "",
searchDate: Date = .now,
sortParameter: SortParameter = .time,
sortOrder: SortOrder = .reverse
) {
_selectedId = selectedId
_selectedIdMap = selectedIdMap

let predicate = Quake.predicate(searchText: searchText, searchDate: searchDate)
switch sortParameter {
case .time: _quakes = Query(filter: predicate, sort: \.time, order: sortOrder)
case .magnitude: _quakes = Query(filter: predicate, sort: \.magnitude, order: sortOrder)
}
}

These two initializers have different sorting constraints to match the needs of their respective appearances, but they use the same predicate to ensure that the set of quakes that appears in the list always matches the set that appears on the map.

## See Also

### Model fetch

`macro Query()`

Fetches all instances of the attached model type.

Supplementary macros that enable you to narrow query results and tell SwiftData how to sort and order those results.

`struct Query`

A type that fetches models using the specified criteria, and manages those models so they remain in sync with the underlying data.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

---

# https://developer.apple.com/documentation/swiftdata/additionalquerymacros

Collection

- SwiftData
- Additional query macros

API Collection

# Additional query macros

Supplementary macros that enable you to narrow query results and tell SwiftData how to sort and order those results.

## Topics

### Basic queries

`macro Query(animation: Animation)`

Fetches all instances of the attached model type, using the specified animation to animate any subsequent changes.

`macro Query(transaction: Transaction)`

Fetches all instances of the attached model type, using the specified transaction to animate any subsequent changes.

### Predicate-based queries

Fetches a sorted subset of the attached model type that satisfy the specified predicate.

Fetches a subset of the attached model type, in a specific order, by sorting on a nonoptional attribute.

Fetches a subset of the attached model type, in a specific order, by sorting on an optional attribute.

Fetches and sorts the subset of the attached model type that satisfy the specified predicate.

### Descriptor-based queries

Fetches only the subset of the attached model type that satisfy the provided fetch descriptor’s criteria.

## See Also

### Model fetch

Filtering and sorting persistent data

Manage data store presentation using predicates and dynamic queries.

`macro Query()`

Fetches all instances of the attached model type.

`struct Query`

A type that fetches models using the specified criteria, and manages those models so they remain in sync with the underlying data.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

---

# https://developer.apple.com/documentation/swiftdata/query

- SwiftData
- Query

Structure

# Query

A type that fetches models using the specified criteria, and manages those models so they remain in sync with the underlying data.

SwiftDataSwiftUI

@MainActor @preconcurrency

## Mentioned in

Preserving your app’s model data across launches

## Topics

### Creating a query

Create a query with a SwiftData fetch descriptor.

Create a query with a predicate, and a list of sort descriptors.

Creates a query with a predicate, a key path to a property for sorting, and the order to sort by.

Create a query with a predicate, a key path to a property for sorting, and the order to sort by.

### Getting query configuration

`var modelContext: ModelContext`

Current model context `Query` interacts with.

`var fetchError: (any Error)?`

An error encountered during the most recent attempt to fetch data.

### Accessing the value

`var wrappedValue: Result`

The most recent fetched result from the Query.

### Updating the value

`func update()`

Updates the underlying value of the stored value.

## Relationships

### Conforms To

- `DynamicProperty`
- `Sendable`
- `SendableMetatype`

## See Also

### Model fetch

Filtering and sorting persistent data

Manage data store presentation using predicates and dynamic queries.

`macro Query()`

Fetches all instances of the attached model type.

Supplementary macros that enable you to narrow query results and tell SwiftData how to sort and order those results.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

---

# https://developer.apple.com/documentation/swiftdata/fetchdescriptor

- SwiftData
- FetchDescriptor

Structure

# FetchDescriptor

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

Swift 5.9+

## Mentioned in

Preserving your app’s model data across launches

## Overview

Use a fetch descriptor to capture the criteria necessary to select, and optionally sort, a specific collection of models from your app’s persistent storage. A fetch descriptor retrieves only a single type of persistent model, and relies on type inference to determine the appropriate type. However, you can configure a fetch descriptor to prefetch related models of different types using the `relationshipKeyPathsForPrefetching` property.

To fetch a collection of models, first create a fetch descriptor and specify a predicate and one or more sort descriptors. The predicate describes the attributes to filter by and the constraints to apply to those attributes. If you don’t specify a predicate, the fetch returns all models of the inferred type. You can further tweak a fetch by limiting the number of models it returns, or indicating whether the fetch evaluates any unsaved changes when it selects the models to return. After configuring the fetch descriptor, pass it to the model context’s `fetch(_:)` method to run the fetch.

predicate: #Predicate { $0.isFavorite == true },
sortBy: [\
.init(\.createdAt)\
]
)
descriptor.fetchLimit = 10

let favoriteRecipes = try modelContext.fetch(descriptor)

If you’re displaying the fetched models in a SwiftUI view, use the descriptor with the `Query(_:animation:)` macro instead.

struct FavoriteRecipesList: View {

predicate: #Predicate { $0.isFavorite == true },
sortBy: [\
.init(\.createdAt)\
]
)
descriptor.fetchLimit = 10
return descriptor
}

@Query(FavoriteRecipesList.fetchDescriptor) private var favoriteRecipes: [Recipe]

var body: some View {
List(favoriteRecipes) { RecipeRowView($0) }
}
}

## Topics

### Creating a fetch descriptor

Creates a fetch descriptor with the specified predicate that, optionally, arranges the fetched models in a particular order.

A logical condition used to test a set of input values for searching or filtering.

A serializable description of how to sort numerics and strings.

### Constraining the fetch

The logical condition that determines whether the fetch includes a specific model in its results.

The sort descriptors that tell the fetch how to order its results.

`var fetchLimit: Int?`

The maximum number of models the fetch can return.

`var fetchOffset: Int?`

The offset of the first matching model to fetch.

`var includePendingChanges: Bool`

A Boolean value that indicates whether, when the fetch runs, it matches against currently unsaved changes in the model context.

### Specifying the fetched attributes

The key paths that identify any related models to include as part of the fetch.

The specific subset of attributes to fetch if you don’t require them all.

## Relationships

### Conforms To

- `Sendable`
- `SendableMetatype`

## See Also

### Model fetch

Filtering and sorting persistent data

Manage data store presentation using predicates and dynamic queries.

`macro Query()`

Fetches all instances of the attached model type.

Supplementary macros that enable you to narrow query results and tell SwiftData how to sort and order those results.

`struct Query`

A type that fetches models using the specified criteria, and manages those models so they remain in sync with the underlying data.

---

# https://developer.apple.com/documentation/swiftdata/maintaining-a-local-copy-of-server-data

- SwiftData
- Maintaining a local copy of server data

Sample Code

# Maintaining a local copy of server data

Create and update a persistent store to cache read-only network data.

Download

Xcode 15.0+

## Overview

This sample app displays a list that contains a day’s worth of earthquakes, showing their time, location, and size. To help people visualize the list, the app also pinpoints each earthquake on a map. You can select an earthquake in the list to highlight it on the map.

The app downloads earthquake data from the network under the following assumptions:

- **Earthquake data is read-only** — The app doesn’t need to synchronize local and remote changes. The server is always the source of truth.

- **New earthquakes happen on a regular basis** — The app needs to provide a way to get an initial list of earthquakes and to periodically refresh that list.

- **Existing earthquake records can change** — For example, the reported magnitude of an earthquake might change as additional measurements become available. The app needs to distinguish between new earthquakes and updates to previously downloaded ones.

The app uses SwiftData to persistently store the data that it downloads. By caching the data locally, the app reduces its need to access the server. SwiftData also makes it easy for the app to manage updates when downloading new data.

### Define the app’s data model

The app represents the information it needs for its interface by defining a `Quake` class. The class definition includes the `Model()` macro to tell the system to store the data persistently using SwiftData:

import SwiftData

@Model
class Quake {
@Attribute(.unique) var code: String
var magnitude: Double
var time: Date
var location: Location
}

The model includes the following fields:

- **A unique code** — By including the `Attribute(_:originalName:hashModifier:)` macro with the `unique` property option, the app ensures that SwiftData stores only one earthquake with a particular value for this field.

- **A magnitude** — The size of the earthquake.

- **A timestamp** — The moment in time when the earthquake happened, stored as a `Date` instance.

- **A location** — A custom `Location` instance that contains a location name and map coordinates:

struct Location: Codable {
var name: String
var longitude: Double
var latitude: Double
}

The `Quake` model can embed a location instance because the `Location` structure conforms to the `Codable` protocol.

### Model the server data

The app loads data from a U.S. Geological Survey (USGS) server, which provides earthquake data in GeoJSON format. To interpret this data, the app defines a `GeoFeatureCollection` structure with property names that match the names of relevant JSON properties:

struct GeoFeatureCollection: Decodable {
let features: [Feature]

struct Feature: Decodable {
let properties: Properties
let geometry: Geometry

struct Properties: Decodable {
let mag: Double
let place: String
let time: Date
let code: String
}

struct Geometry: Decodable {
let coordinates: [Double]
}
}
}

The structure and its substructures include elements relevant to this app, namely magnitude, time, and location information. They omit many other fields that the server provides because the app doesn’t need them. The structure also conforms to the `Decodable` protocol so the app can use the structure to decode the downloaded data.

### Download data from the server

To retrieve data, the app defines a `fetchFeatures()` method that uses a `URLSession` to store the earthquake JSON in a `data` property:

let session = URLSession.shared
guard let (data, response) = try? await session.data(from: url),
let httpResponse = response as? HTTPURLResponse,
httpResponse.statusCode == 200
else {
throw DownloadError.missingData
}

The method then parses the data with a `JSONDecoder` instance, according to the definition provided by the decodable `GeoFeatureCollection` structure:

do {
let jsonDecoder = JSONDecoder()
jsonDecoder.dateDecodingStrategy = .millisecondsSince1970
return try jsonDecoder.decode(GeoFeatureCollection.self, from: data)
} catch {
throw DownloadError.wrongDataFormat(error: error)
}

For other examples of decoding JSON data, see Using JSON with Custom Types.

### Translate server data into model data

After retrieving a collection of features, the app interprets each feature as an earthquake. The `Quake` class defines a convenience initializer that creates a new earthquake from a feature instance:

convenience init(from feature: GeoFeatureCollection.Feature) {
self.init(
code: feature.properties.code,
magnitude: feature.properties.mag,
time: feature.properties.time,
name: feature.properties.place,
longitude: feature.geometry.coordinates[0],
latitude: feature.geometry.coordinates[1]
)
}

This enables the app to translate the data from a format that the server provides to a format that’s convenient for the app. For example, the initializer converts longitude and latitude coordinates that appear as anonymous elements in the feature’s `geometry.coordinates` array into named parameters.

### Insert or update new earthquake data

As the app creates new earthquake instances, it persistently stores any that have a magnitude greater than zero by calling the model context’s `insert(_:)` method for each one:

for feature in featureCollection.features {
let quake = Quake(from: feature)

modelContext.insert(quake)
}
}

The app runs this loop for both the initial download and later refresh operations. When the app saves the changes — which happens automatically in this case because the context’s `autosaveEnabled` property has the default value of `true` — SwiftData checks if the specified earthquake’s `code` parameter matches the code of an earthquake that’s already in the store. If so, the framework updates the stored earthquake’s other parameters using the values in the specified one. Otherwise, the framework adds a new earthquake to the store.

The insert method works for both creating and updating earthquake model instances because the model indicates that the `code` parameter is unique. This relies on the fact that the server ensures a unique, stable code for each earthquake event.

## See Also

### Model storage

`class DefaultStore`

A data store that uses Core Data as its undelying storage mechanism.

`protocol DataStore`

An interface that enables SwiftData to read and write model data without knowledge of the underlying storage mechanism.

`protocol DataStoreBatching`

An interface that enables a custom data store to support batch requests.

`protocol HistoryProviding`

An interface that enables a custom data store to provide the history of changes for its persisted models.

Building a document-based app using SwiftData

Code along with the WWDC presenter to transform an app with SwiftData.

`struct ModelDocument`

A document type that uses SwiftData to manage its storage.

---

# https://developer.apple.com/documentation/swiftdata/defaultstore

- SwiftData
- DefaultStore

Class

# DefaultStore

A data store that uses Core Data as its undelying storage mechanism.

Swift 5.9+

final class DefaultStore

## Topics

### Creating a data store

`convenience init(ModelConfiguration, migrationPlan: (any SchemaMigrationPlan.Type)?) throws`

### Accessing store information

`let configuration: ModelConfiguration`

`typealias Configuration`

`var identifier: String`

`let name: String`

`let schema: Schema`

### Processing fetch requests

`typealias Snapshot`

`struct DefaultSnapshot`

### Deleting persisted model data

`func erase() throws`

### Sharing cached data between model contexts

`func initializeState(for: EditingState)`

`func invalidateState(for: EditingState)`

### Managing model change history

`typealias HistoryType`

`typealias TokenType`

## Relationships

### Conforms To

- `Copyable`
- `DataStore`
- `DataStoreBatching`
- `HistoryProviding`

## See Also

### Model storage

Maintaining a local copy of server data

Create and update a persistent store to cache read-only network data.

`protocol DataStore`

An interface that enables SwiftData to read and write model data without knowledge of the underlying storage mechanism.

`protocol DataStoreBatching`

An interface that enables a custom data store to support batch requests.

`protocol HistoryProviding`

An interface that enables a custom data store to provide the history of changes for its persisted models.

Building a document-based app using SwiftData

Code along with the WWDC presenter to transform an app with SwiftData.

`struct ModelDocument`

A document type that uses SwiftData to manage its storage.

---

# https://developer.apple.com/documentation/swiftdata/datastore



---

# https://developer.apple.com/documentation/swiftdata/datastorebatching

- SwiftData
- DataStoreBatching

Protocol

# DataStoreBatching

An interface that enables a custom data store to support batch requests.

Swift 5.9+

protocol DataStoreBatching : DataStore

## Topics

### Deleting persisted model data

**Required**

`struct DataStoreBatchDeleteRequest`

## Relationships

### Inherits From

- `DataStore`

### Conforming Types

- `DefaultStore`

## See Also

### Model storage

Maintaining a local copy of server data

Create and update a persistent store to cache read-only network data.

`class DefaultStore`

A data store that uses Core Data as its undelying storage mechanism.

`protocol DataStore`

An interface that enables SwiftData to read and write model data without knowledge of the underlying storage mechanism.

`protocol HistoryProviding`

An interface that enables a custom data store to provide the history of changes for its persisted models.

Building a document-based app using SwiftData

Code along with the WWDC presenter to transform an app with SwiftData.

`struct ModelDocument`

A document type that uses SwiftData to manage its storage.

---

# https://developer.apple.com/documentation/swiftdata/historyproviding

- SwiftData
- HistoryProviding

Protocol

# HistoryProviding

An interface that enables a custom data store to provide the history of changes for its persisted models.

Swift 5.9+

protocol HistoryProviding

## Topics

### Processing history fetch requests

**Required**

### Deleting history

### Getting the history transaction type

`associatedtype HistoryType : HistoryTransaction`

### Type Properties

`static var historyType: Self.HistoryType.Type`

## Relationships

### Conforming Types

- `DefaultStore`

## See Also

### Model storage

Maintaining a local copy of server data

Create and update a persistent store to cache read-only network data.

`class DefaultStore`

A data store that uses Core Data as its undelying storage mechanism.

`protocol DataStore`

An interface that enables SwiftData to read and write model data without knowledge of the underlying storage mechanism.

`protocol DataStoreBatching`

An interface that enables a custom data store to support batch requests.

Building a document-based app using SwiftData

Code along with the WWDC presenter to transform an app with SwiftData.

`struct ModelDocument`

A document type that uses SwiftData to manage its storage.

---

# https://developer.apple.com/documentation/swiftdata/modeldocument

- SwiftData
- ModelDocument

Structure

# ModelDocument

A document type that uses SwiftData to manage its storage.

SwiftDataSwiftUI

struct ModelDocument

## Overview

## See Also

### Model storage

Maintaining a local copy of server data

Create and update a persistent store to cache read-only network data.

`class DefaultStore`

A data store that uses Core Data as its undelying storage mechanism.

`protocol DataStore`

An interface that enables SwiftData to read and write model data without knowledge of the underlying storage mechanism.

`protocol DataStoreBatching`

An interface that enables a custom data store to support batch requests.

`protocol HistoryProviding`

An interface that enables a custom data store to provide the history of changes for its persisted models.

Building a document-based app using SwiftData

Code along with the WWDC presenter to transform an app with SwiftData.

---

# https://developer.apple.com/documentation/swiftdata/historychange

- SwiftData
- HistoryChange

Enumeration

# HistoryChange

Values that describe data history transactions.

Swift 5.9+

enum HistoryChange

## Topics

### Operations

`case delete(any HistoryDelete)`

A value that indicates a delete operation.

`case insert(any HistoryInsert)`

A value that indicates an insertion operation.

`case update(any HistoryUpdate)`

A value that indicates an update operation.

### Getting information about a change

`var changedPersistentIdentifier: PersistentIdentifier`

The persistent identifier of the change.

## Relationships

### Conforms To

- `Sendable`
- `SendableMetatype`

## See Also

### History life cycle

`protocol HistoryDelete`

An interface that enables a custom data store to delete items from the history of changes to its persisted models.

`protocol HistoryInsert`

`protocol HistoryToken`

`protocol HistoryTransaction`

`protocol HistoryUpdate`

`struct HistoryTombstone`

`struct DefaultHistoryInsert`

`struct DefaultHistoryUpdate`

`struct DefaultHistoryDelete`

`struct DefaultHistoryToken`

`struct DefaultHistoryTransaction`

---

# https://developer.apple.com/documentation/swiftdata/historydelete



---

# https://developer.apple.com/documentation/swiftdata/historyinsert



---

# https://developer.apple.com/documentation/swiftdata/historytoken



---

# https://developer.apple.com/documentation/swiftdata/historytransaction



---

# https://developer.apple.com/documentation/swiftdata/historyupdate



---

# https://developer.apple.com/documentation/swiftdata/historytombstone



---

# https://developer.apple.com/documentation/swiftdata/defaulthistoryinsert



---

# https://developer.apple.com/documentation/swiftdata/defaulthistoryupdate



---

# https://developer.apple.com/documentation/swiftdata/defaulthistorydelete



---

# https://developer.apple.com/documentation/swiftdata/defaulthistorytoken



---

# https://developer.apple.com/documentation/swiftdata/defaulthistorytransaction

- SwiftData
- DefaultHistoryTransaction

Structure

# DefaultHistoryTransaction

Swift 5.9+

struct DefaultHistoryTransaction

## Topics

### Operators

Returns a Boolean value indicating whether two values are equal.

### Instance Properties

`let author: String?`

`let bundleIdentifier: String`

[`let changes: [HistoryChange]`](https://developer.apple.com/documentation/swiftdata/defaulthistorytransaction/changes)

`var hashValue: Int`

The hash value.

`var id: Int64`

The stable identity of the entity associated with this instance.

`let processIdentifier: String`

`let storeIdentifier: String`

`let timestamp: Date`

`let token: DefaultHistoryTransaction.TokenType`

`let transactionIdentifier: DefaultHistoryTransaction.TransactionIdentifier`

### Instance Methods

`func hash(into: inout Hasher)`

Hashes the essential components of this value by feeding them into the given hasher.

### Type Aliases

`typealias ID`

A type representing the stable identity of the entity associated with an instance.

`typealias TokenType`

`typealias TransactionIdentifier`

## Relationships

### Conforms To

- `Equatable`
- `Hashable`
- `HistoryTransaction`
- `Identifiable`
- `Sendable`
- `SendableMetatype`

## See Also

### History life cycle

`enum HistoryChange`

Values that describe data history transactions.

`protocol HistoryDelete`

An interface that enables a custom data store to delete items from the history of changes to its persisted models.

`protocol HistoryInsert`

`protocol HistoryToken`

`protocol HistoryTransaction`

`protocol HistoryUpdate`

`struct HistoryTombstone`

`struct DefaultHistoryInsert`

`struct DefaultHistoryUpdate`

`struct DefaultHistoryDelete`

`struct DefaultHistoryToken`

---

# https://developer.apple.com/documentation/swiftdata/datastoresnapshotcodingkey

- SwiftData
- DataStoreSnapshotCodingKey

Enumeration

# DataStoreSnapshotCodingKey

The key space to use when implementing custom coders and decoders for data store snapshots,

Swift 5.9+

enum DataStoreSnapshotCodingKey

## Topics

### Creating a coding key

`init?(stringValue: String)`

Creates a new instance from the given string.

### Values that describe coding keys

`case persistentIdentifier`

A value that represents a persistent identifier.

### Instance Properties

`var intValue: Int?`

The value to use in an integer-indexed collection, such as an integer-keyed dictionary.

`var stringValue: String`

The string to use in a named collection (e.g. a string-keyed dictionary).

### Enumeration Cases

`case modeledProperty(String)`

A value that represents the name of the modeled property.

### Initializers

`init?(intValue: Int)`

Creates a new instance from the specified integer.

## Relationships

### Conforms To

- `CodingKey`
- `CustomDebugStringConvertible`
- `CustomStringConvertible`
- `Sendable`
- `SendableMetatype`

---

# https://developer.apple.com/documentation/swiftdata/swiftdataerror

- SwiftData
- SwiftDataError

Structure

# SwiftDataError

A type that describes a SwiftData error.

Swift 5.9+

struct SwiftDataError

## Topics

### Fetch errors

`static let includePendingChangesWithBatchSize: SwiftDataError`

`static let sortingPendingChangesWithIdentifiers: SwiftDataError`

`static let unsupportedKeyPath: SwiftDataError`

`static let unsupportedPredicate: SwiftDataError`

`static let unsupportedSortDescriptor: SwiftDataError`

### Configuration errors

`static let configurationFileNameContainsInvalidCharacters: SwiftDataError`

`static let configurationFileNameTooLong: SwiftDataError`

`static let configurationSchemaNotFoundInContainerSchema: SwiftDataError`

`static let duplicateConfiguration: SwiftDataError`

### Container errors

`static let loadIssueModelContainer: SwiftDataError`

### Context errors

`static let modelValidationFailure: SwiftDataError`

`static let missingModelContext: SwiftDataError`

### Migration errors

`static let backwardMigration: SwiftDataError`

`static let unknownSchema: SwiftDataError`

### Operators

Returns a Boolean value indicating whether two values are equal.

### Instance Properties

`var hashValue: Int`

The hash value.

### Instance Methods

`func hash(into: inout Hasher)`

Hashes the essential components of this value by feeding them into the given hasher.

### Type Properties

`static let historyTokenExpired: SwiftDataError`

`static let invalidTransactionFetchRequest: SwiftDataError`

## Relationships

### Conforms To

- `Equatable`
- `Error`
- `Hashable`
- `Sendable`
- `SendableMetatype`

## See Also

### Errors

`enum DataStoreError`

A type that describes a data store error.

---

# https://developer.apple.com/documentation/swiftdata/datastoreerror

- SwiftData
- DataStoreError

Enumeration

# DataStoreError

A type that describes a data store error.

Swift 5.9+

enum DataStoreError

## Topics

### Getting error codes

`case invalidPredicate`

`case preferInMemoryFilter`

`case preferInMemorySort`

`case unsupportedFeature`

### Comparing errors

Returns a Boolean value indicating whether two values are equal.

### Hashing errors

`var hashValue: Int`

The hash value.

`func hash(into: inout Hasher)`

Hashes the essential components of this value by feeding them into the given hasher.

## Relationships

### Conforms To

- `Copyable`
- `Equatable`
- `Error`
- `Hashable`
- `Sendable`
- `SendableMetatype`

## See Also

### Errors

`struct SwiftDataError`

A type that describes a SwiftData error.

---

# https://developer.apple.com/documentation/swiftdata/model())



---

# https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/relationship(_:deleterule:minimummodelcount:maximummodelcount:originalname:inverse:hashmodifier:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/modelcontext)



---

# https://developer.apple.com/documentation/swiftdata/query())



---

# https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)



---

# https://developer.apple.com/documentation/swiftdata/adding-and-editing-persistent-data-in-your-app)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/adopting-inheritance-in-swiftdata)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/unique(_:))



---

# https://developer.apple.com/documentation/swiftdata/index(_:)-74ia2)



---

# https://developer.apple.com/documentation/swiftdata/index(_:)-7d4z0)



---

# https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/transient())



---

# https://developer.apple.com/documentation/swiftdata/modelcontainer)



---

# https://developer.apple.com/documentation/swiftdata/fetching-and-filtering-time-based-model-changes)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/historydescriptor)



---

# https://developer.apple.com/documentation/swiftdata/deleting-persistent-data-from-your-app)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/reverting-data-changes-using-the-undo-manager)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/concurrencysupport)



---

# https://developer.apple.com/documentation/swiftdata/filtering-and-sorting-persistent-data)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/additionalquerymacros)



---

# https://developer.apple.com/documentation/swiftdata/query)



---

# https://developer.apple.com/documentation/swiftdata/fetchdescriptor)



---

# https://developer.apple.com/documentation/swiftdata/maintaining-a-local-copy-of-server-data)



---

# https://developer.apple.com/documentation/swiftdata/defaultstore)



---

# https://developer.apple.com/documentation/swiftdata/datastore)



---

# https://developer.apple.com/documentation/swiftdata/datastorebatching)



---

# https://developer.apple.com/documentation/swiftdata/historyproviding)



---

# https://developer.apple.com/documentation/swiftdata/modeldocument)



---

# https://developer.apple.com/documentation/swiftdata/historychange)



---

# https://developer.apple.com/documentation/swiftdata/historydelete)



---

# https://developer.apple.com/documentation/swiftdata/historyinsert)



---

# https://developer.apple.com/documentation/swiftdata/historytoken)



---

# https://developer.apple.com/documentation/swiftdata/historytransaction)



---

# https://developer.apple.com/documentation/swiftdata/historyupdate)



---

# https://developer.apple.com/documentation/swiftdata/historytombstone)



---

# https://developer.apple.com/documentation/swiftdata/defaulthistoryinsert)



---

# https://developer.apple.com/documentation/swiftdata/defaulthistoryupdate)



---

# https://developer.apple.com/documentation/swiftdata/defaulthistorydelete)



---

# https://developer.apple.com/documentation/swiftdata/defaulthistorytoken)



---

# https://developer.apple.com/documentation/swiftdata/defaulthistorytransaction)



---

# https://developer.apple.com/documentation/swiftdata/datastoresnapshotcodingkey)



---

# https://developer.apple.com/documentation/swiftdata/swiftdataerror)



---

# https://developer.apple.com/documentation/swiftdata/datastoreerror)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.Option

Structure

# Schema.Relationship.Option

Swift 5.9+

struct Option

## Topics

### Operators

Returns a Boolean value indicating whether two values are equal.

### Initializers

`init(from: any Decoder) throws`

Creates a new instance by decoding from the given decoder.

### Instance Properties

`var debugDescription: String`

A textual representation of this instance, suitable for debugging.

`var hashValue: Int`

The hash value.

### Instance Methods

`func encode(to: any Encoder) throws`

Encodes this value into the given encoder.

`func hash(into: inout Hasher)`

Hashes the essential components of this value by feeding them into the given hasher.

### Type Properties

`static var unique: Schema.Relationship.Option`

Ensures the property’s value is unique across all models of the same type.

## Relationships

### Conforms To

- `CustomDebugStringConvertible`
- `Decodable`
- `Encodable`
- `Equatable`
- `Hashable`

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.DeleteRule

Enumeration

# Schema.Relationship.DeleteRule

Describes the rule to apply when deleting a model containing references to other models.

Swift 5.9+

enum DeleteRule

## Mentioned in

Preserving your app’s model data across launches

## Topics

### Accessing delete rules

`case cascade`

A rule that deletes any related models.

`case deny`

A rule that prevents the deletion of a model because it contains one or more references to other models.

`case noAction`

A rule that doesn’t make changes to any related models.

`case nullify`

A rule that nullifies the related model’s reference to the deleted model.

### Creating a relationship delete rule

`init?(rawValue: String)`

Creates a new instance with the specified raw value.

### Instance Properties

`var rawValue: String`

The corresponding value of the raw type.

### Type Aliases

`typealias RawValue`

The raw type that can be used to represent all values of the conforming type.

## Relationships

### Conforms To

- `Copyable`
- `Decodable`
- `Encodable`
- `Equatable`
- `Hashable`
- `RawRepresentable`

## See Also

### Managing the configuration

`var keypath: AnyKeyPath?`

`var destination: String`

`var inverseName: String?`

`var inverseKeyPath: AnyKeyPath?`

`var deleteRule: Schema.Relationship.DeleteRule`

`var isToOneRelationship: Bool`

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/nullify

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.DeleteRule
- Schema.Relationship.DeleteRule.nullify

Case

# Schema.Relationship.DeleteRule.nullify

A rule that nullifies the related model’s reference to the deleted model.

Swift 5.9+

case nullify

## See Also

### Accessing delete rules

`case cascade`

A rule that deletes any related models.

`case deny`

A rule that prevents the deletion of a model because it contains one or more references to other models.

`case noAction`

A rule that doesn’t make changes to any related models.

---

# https://developer.apple.com/documentation/swiftdata/RemoteImage



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option).



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum).

.#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/nullify).



---

# https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes).



---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option

- SwiftData
- Schema
- Schema.Attribute
- Schema.Attribute.Option

Structure

# Schema.Attribute.Option

Swift 5.9+

struct Option

## Topics

### Accessing property options

`static var allowsCloudEncryption: Schema.Attribute.Option`

Stores the property’s value in an encrypted form.

`static var externalStorage: Schema.Attribute.Option`

Stores the property’s value as binary data adjacent to the model storage.

`static var preserveValueOnDeletion: Schema.Attribute.Option`

Preserves the property’s value in the persistent history when the context deletes the owning model.

`static var spotlight: Schema.Attribute.Option`

Indexes the property’s value so it can appear in Spotlight search results.

`static var unique: Schema.Attribute.Option`

Ensures the property’s value is unique across all models of the same type.

Transforms the property’s value between an in-memory form and a persisted form.

### Type Properties

`static var ephemeral: Schema.Attribute.Option`

Track changes to this property but do not persist

## Relationships

### Conforms To

- `Copyable`
- `CustomDebugStringConvertible`
- `Decodable`
- `Encodable`
- `Equatable`
- `Hashable`

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option).



---

# https://developer.apple.com/documentation/swiftdata/persistentmodel

- SwiftData
- PersistentModel

Protocol

# PersistentModel

An interface that enables SwiftData to manage a Swift class as a stored model.

Swift 5.9+

protocol PersistentModel : AnyObject, Observable, Hashable, Identifiable

## Mentioned in

Preserving your app’s model data across launches

## Topics

### Creating a persistent model

**Required**

### Identifying the model instance

`var persistentModelID: PersistentIdentifier`

`struct PersistentIdentifier`

A type that describes the aggregate identity of a SwiftData model.

`var modelContext: ModelContext?`

### Accessing supplementary information

[`static var schemaMetadata: [Schema.PropertyMetadata]`](https://developer.apple.com/documentation/swiftdata/persistentmodel/schemametadata)

`var hasChanges: Bool`

`var isDeleted: Bool`

### Internal

Restricted-use symbols that the framework requires for macro expansion and other internal tasks.

### Associated Types

`associatedtype Root : PersistentModel = Self`

### Type Methods

`](https://developer.apple.com/documentation/swiftdata/persistentmodel/createbackingdata())

## Relationships

### Inherits From

- `Equatable`
- `Hashable`
- `Identifiable`
- `Observable`

## See Also

### Creating a model container

[`init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: [ModelConfiguration]) throws`](https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:migrationplan:configurations:)-1czix)

Creates a model container using the specified schema, migration plan, and configurations.

`convenience init(for: any PersistentModel.Type..., migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified model types, migration plan, and zero or more configurations.

`convenience init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified schema, migration plan, and zero or more configurations.

`struct ModelConfiguration`

A type that describes the configuration of an app’s schema or specific group of models.

`class Schema`

An object that maps model classes to data in the model store, and helps with the migration of that data between releases.

`protocol SchemaMigrationPlan`

An interface for describing the evolution of a schema and how to migrate between specific versions.

---

# https://developer.apple.com/documentation/swiftdata/persistentmodel)



---

# https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches).

.#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/save()

#app-main)

- SwiftData
- ModelContext
- save()

Instance Method

# save()

Writes any pending inserts, changes, and deletes to the persistent storage.

Swift 5.9+

func save() throws

## Mentioned in

Preserving your app’s model data across launches

## Discussion

## See Also

### Persisting unsaved changes

`var autosaveEnabled: Bool`

A Boolean value that indicates whether the context should automatically save any pending changes when certain events occur.

Runs the provided closure, and once it finishes, writes any pending inserts, changes, and deletes to the persistent storage.

`func rollback()`

Discards pending inserts and deletes, restores changed models to their most recent committed state, and empties the undo stack.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/autosaveenabled

- SwiftData
- ModelContext
- autosaveEnabled

Instance Property

# autosaveEnabled

A Boolean value that indicates whether the context should automatically save any pending changes when certain events occur.

Swift 5.9+

var autosaveEnabled: Bool { get set }

## Mentioned in

Preserving your app’s model data across launches

## Discussion

When `true`, the context calls `save()` after you make changes to any inserted or registered models. The context also calls `save()` at various times during the lifecycle of windows, scenes, views, and sheets.

The default value is `false`. SwiftData automatically sets this property to `true` for the model container’s `mainContext`.

## See Also

### Persisting unsaved changes

`func save() throws`

Writes any pending inserts, changes, and deletes to the persistent storage.

Runs the provided closure, and once it finishes, writes any pending inserts, changes, and deletes to the persistent storage.

`func rollback()`

Discards pending inserts and deletes, restores changed models to their most recent committed state, and empties the undo stack.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/insert(_:)

#app-main)

- SwiftData
- ModelContext
- insert(\_:)

Instance Method

# insert(\_:)

Registers the specified model with the context so it can include the model in the next save operation.

Swift 5.9+

## Parameters

`model`

The model to include in the next save operation.

## Discussion

A model is given a temporary persistent identifier until the first time a context saves it, after which that context assigns a permanent identifier. If you call `rollback()` after inserting a model but before the next save operation, the context discards that model.

## See Also

### Inserting models

[`var insertedModelsArray: [any PersistentModel]`](https://developer.apple.com/documentation/swiftdata/modelcontext/insertedmodelsarray)

The array of inserted models that the context is yet to persist.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/delete(_:)

#app-main)

- SwiftData
- ModelContext
- delete(\_:)

Instance Method

# delete(\_:)

Removes the specified model from the persistent storage during the next save operation.

Swift 5.9+

## Parameters

`model`

The persistent model to delete.

## Discussion

When the context nexts commits its changes, SwiftData removes the model from the persistent storage. If the model is new and in an unsaved state, the context simply discards it.

## See Also

### Deleting models

[`var deletedModelsArray: [any PersistentModel]`](https://developer.apple.com/documentation/swiftdata/modelcontext/deletedmodelsarray)

The array of registered models that the context will remove from the persistent storage during the next save operation.

Removes each model satisfying the given predicate from the persistent storage during the next save operation.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/delete(model:where:includesubclasses:)

#app-main)

- SwiftData
- ModelContext
- delete(model:where:includeSubclasses:)

Instance Method

# delete(model:where:includeSubclasses:)

Removes each model satisfying the given predicate from the persistent storage during the next save operation.

Swift 5.9+

model: T.Type,

includeSubclasses: Bool = true
) throws where T : PersistentModel

## Parameters

`model`

The type of the model to remove.

`predicate`

The logical condition to use when determining if the context should remove a particular model. The default value is `nil`.

`includeSubclasses`

A Boolean value that indicates whether the context includes subclasses of the specified model type when evaluating models to remove. The default value is `true`.

## Discussion

## See Also

### Deleting models

[`var deletedModelsArray: [any PersistentModel]`](https://developer.apple.com/documentation/swiftdata/modelcontext/deletedmodelsarray)

The array of registered models that the context will remove from the persistent storage during the next save operation.

Removes the specified model from the persistent storage during the next save operation.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/haschanges

- SwiftData
- ModelContext
- hasChanges

Instance Property

# hasChanges

A Boolean value that indicates whether the context has unsaved changes.

Swift 5.9+

var hasChanges: Bool { get }

## See Also

### Modifying models

[`var changedModelsArray: [any PersistentModel]`](https://developer.apple.com/documentation/swiftdata/modelcontext/changedmodelsarray)

The array of registered models that have unsaved changes.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/rollback()

#app-main)

- SwiftData
- ModelContext
- rollback()

Instance Method

# rollback()

Discards pending inserts and deletes, restores changed models to their most recent committed state, and empties the undo stack.

Swift 5.9+

func rollback()

## See Also

### Persisting unsaved changes

`var autosaveEnabled: Bool`

A Boolean value that indicates whether the context should automatically save any pending changes when certain events occur.

`func save() throws`

Writes any pending inserts, changes, and deletes to the persistent storage.

Runs the provided closure, and once it finishes, writes any pending inserts, changes, and deletes to the persistent storage.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetch(_:)

#app-main)

- SwiftData
- ModelContext
- fetch(\_:)

Instance Method

# fetch(\_:)

Returns an array of typed models that match the criteria of the specified fetch descriptor.

Swift 5.9+

## Parameters

`descriptor`

A fetch descriptor that provides the configuration for the fetch.

## Return Value

The array of typed models that satisfy the criteria of the fetch descriptor. If no models match the criteria, the array is empty.

## See Also

### Fetching models

Returns a collection of typed models, in batches, which match the criteria of the specified fetch descriptor.

Returns the number of models that match the criteria of the specified fetch descriptor.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

`struct FetchResultsCollection`

A collection that efficiently provides the results of a completed fetch.

Runs a closure for each model that matches the criteria of the specified fetch descriptor.

Returns the persistent model for the specified identifier.

Returns the typed model for the specified identifier.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetch(_:batchsize:)

#app-main)

- SwiftData
- ModelContext
- fetch(\_:batchSize:)

Instance Method

# fetch(\_:batchSize:)

Returns a collection of typed models, in batches, which match the criteria of the specified fetch descriptor.

Swift 5.9+

batchSize: Int

## Parameters

`descriptor`

A fetch descriptor that provides the configuration for the fetch.

`batchSize`

The maximum number of models to include in each batch.

## Return Value

The collection of typed models that satisfy the criteria of the fetch descriptor. If no models match the criteria, the collection is empty.

## Discussion

As you access the models in the returned collection (either sequentially, or directly using subscripting), the context automatically fetches the necessary batches.

## See Also

### Fetching models

Returns an array of typed models that match the criteria of the specified fetch descriptor.

Returns the number of models that match the criteria of the specified fetch descriptor.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

`struct FetchResultsCollection`

A collection that efficiently provides the results of a completed fetch.

Runs a closure for each model that matches the criteria of the specified fetch descriptor.

Returns the persistent model for the specified identifier.

Returns the typed model for the specified identifier.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetchcount(_:)

#app-main)

- SwiftData
- ModelContext
- fetchCount(\_:)

Instance Method

# fetchCount(\_:)

Returns the number of models that match the criteria of the specified fetch descriptor.

Swift 5.9+

## Parameters

`descriptor`

A fetch descriptor that provides the configuration for the fetch.

## Return Value

The total number of models that satisfy the criteria of the fetch descriptor.

## See Also

### Fetching models

Returns an array of typed models that match the criteria of the specified fetch descriptor.

Returns a collection of typed models, in batches, which match the criteria of the specified fetch descriptor.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

`struct FetchResultsCollection`

A collection that efficiently provides the results of a completed fetch.

Runs a closure for each model that matches the criteria of the specified fetch descriptor.

Returns the persistent model for the specified identifier.

Returns the typed model for the specified identifier.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetchidentifiers(_:)

#app-main)

- SwiftData
- ModelContext
- fetchIdentifiers(\_:)

Instance Method

# fetchIdentifiers(\_:)

Returns an array of persistent identifiers, where each identifier represents a single model that satisfies the criteria of the specified fetch descriptor.

Swift 5.9+

## Parameters

`descriptor`

A fetch descriptor that provides the configuration for the fetch.

## Return Value

The array of persistent identifiers. If no models match the descriptor’s criteria, the array is empty.

## See Also

### Fetching only persistent identifiers

Returns a collection of persistent identifiers, in batches, where each identifier represents a single model that satisfies the criteria of the specified fetch descriptor.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetchidentifiers(_:batchsize:)

#app-main)

- SwiftData
- ModelContext
- fetchIdentifiers(\_:batchSize:)

Instance Method

# fetchIdentifiers(\_:batchSize:)

Returns a collection of persistent identifiers, in batches, where each identifier represents a single model that satisfies the criteria of the specified fetch descriptor.

Swift 5.9+

batchSize: Int

## Parameters

`descriptor`

A fetch descriptor that provides the configuration for the fetch.

`batchSize`

The maximum number of identifiers to include in each batch.

## Return Value

The collection of persistent identifiers. If no models match the descriptor’s criteria, the array is empty.

## Discussion

The collection automatically fetches subsequent batches as you iterate over the identifiers, or access one at a specific index.

## See Also

### Fetching only persistent identifiers

Returns an array of persistent identifiers, where each identifier represents a single model that satisfies the criteria of the specified fetch descriptor.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/willsave

- SwiftData
- ModelContext
- willSave

Type Property

# willSave

A notification that posts when the context is about to process pending inserts, changes, and deletes.

Swift 5.9+

static let willSave: Notification.Name

## Discussion

## See Also

### Registering for notifications

`static let didSave: Notification.Name`

A notification that posts when the context finishes processing pending inserts, changes, and deletes.

`enum NotificationKey`

Describes the data in the user info dictionary of a notification sent by a model context.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/didsave

- SwiftData
- ModelContext
- didSave

Type Property

# didSave

A notification that posts when the context finishes processing pending inserts, changes, and deletes.

Swift 5.9+

static let didSave: Notification.Name

## Discussion

The notification’s `userInfo` dictionary contains the persistent identifiers of any inserted, updated, or deleted models. Use the appropriate key to access those identifiers. For more information, see `ModelContext.NotificationKey`.

## See Also

### Registering for notifications

`static let willSave: Notification.Name`

A notification that posts when the context is about to process pending inserts, changes, and deletes.

`enum NotificationKey`

Describes the data in the user info dictionary of a notification sent by a model context.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/init(_:)



---

# https://developer.apple.com/documentation/swiftdata/fetchresultscollection

- SwiftData
- FetchResultsCollection

Structure

# FetchResultsCollection

A collection that efficiently provides the results of a completed fetch.

Swift 5.9+

## Topics

### Accessing a specific result

Accesses the element at the specified position.

### Accessing indices

`var startIndex: Int`

The position of the first element in a nonempty collection.

`var endIndex: Int`

The collection’s “past the end” position—that is, the position one greater than the last valid subscript argument.

### Type Aliases

`typealias Index`

A type that represents a position in the collection.

`typealias Indices`

A type that represents the indices that are valid for subscripting the collection, in ascending order.

`typealias Iterator`

A type that provides the collection’s iteration interface and encapsulates its iteration state.

`typealias SubSequence`

A collection representing a contiguous subrange of this collection’s elements. The subsequence shares indices with the original collection.

## Relationships

### Conforms To

- `BidirectionalCollection`
- `Collection`
- `RandomAccessCollection`
- `Sequence`

## See Also

### Fetching models

Returns an array of typed models that match the criteria of the specified fetch descriptor.

Returns a collection of typed models, in batches, which match the criteria of the specified fetch descriptor.

Returns the number of models that match the criteria of the specified fetch descriptor.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

Runs a closure for each model that matches the criteria of the specified fetch descriptor.

Returns the persistent model for the specified identifier.

Returns the typed model for the specified identifier.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/enumerate(_:batchsize:allowescapingmutations:block:)

#app-main)

- SwiftData
- ModelContext
- enumerate(\_:batchSize:allowEscapingMutations:block:)

Instance Method

# enumerate(\_:batchSize:allowEscapingMutations:block:)

Runs a closure for each model that matches the criteria of the specified fetch descriptor.

Swift 5.9+

batchSize: Int = 5000,
allowEscapingMutations: Bool = false,

) throws where T : PersistentModel

## Parameters

`fetch`

A fetch descriptor that provides the configuration for the fetch.

`batchSize`

The maximum number of models to include in each batch. The default value is 5000.

`allowEscapingMutations`

A Boolean value that determines whether the closure can leave the context in a modified state after it completes. The default value is `false`.

`block`

The closure to run for each fetched model.

## See Also

### Fetching models

Returns an array of typed models that match the criteria of the specified fetch descriptor.

Returns a collection of typed models, in batches, which match the criteria of the specified fetch descriptor.

Returns the number of models that match the criteria of the specified fetch descriptor.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

`struct FetchResultsCollection`

A collection that efficiently provides the results of a completed fetch.

Returns the persistent model for the specified identifier.

Returns the typed model for the specified identifier.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/model(for:)

#app-main)

- SwiftData
- ModelContext
- model(for:)

Instance Method

# model(for:)

Returns the persistent model for the specified identifier.

Swift 5.9+

## Parameters

`persistentModelID`

The identifier of the model to fetch. For more information, see `PersistentIdentifier`.

## Return Value

The identified persistent model, if known to the context; otherwise, an unsaved model with its `persistentModelID` property set to `persistentModelID`.

## See Also

### Fetching models

Returns an array of typed models that match the criteria of the specified fetch descriptor.

Returns a collection of typed models, in batches, which match the criteria of the specified fetch descriptor.

Returns the number of models that match the criteria of the specified fetch descriptor.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

`struct FetchResultsCollection`

A collection that efficiently provides the results of a completed fetch.

Runs a closure for each model that matches the criteria of the specified fetch descriptor.

Returns the typed model for the specified identifier.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/registeredmodel(for:)

#app-main)

- SwiftData
- ModelContext
- registeredModel(for:)

Instance Method

# registeredModel(for:)

Returns the typed model for the specified identifier.

Swift 5.9+

## Parameters

`persistentModelID`

The identifier of the model to fetch. For more information, see `PersistentIdentifier`.

## Return Value

A typed instance of the identified model, if known to the context; otherwise, `nil`.

## See Also

### Fetching models

Returns an array of typed models that match the criteria of the specified fetch descriptor.

Returns a collection of typed models, in batches, which match the criteria of the specified fetch descriptor.

Returns the number of models that match the criteria of the specified fetch descriptor.

`struct FetchDescriptor`

A type that describes the criteria, sort order, and any additional configuration to use when performing a fetch.

`struct FetchResultsCollection`

A collection that efficiently provides the results of a completed fetch.

Runs a closure for each model that matches the criteria of the specified fetch descriptor.

Returns the persistent model for the specified identifier.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/transaction(block:)

#app-main)

- SwiftData
- ModelContext
- transaction(block:)

Instance Method

# transaction(block:)

Runs the provided closure, and once it finishes, writes any pending inserts, changes, and deletes to the persistent storage.

Swift 5.9+

## Parameters

`block`

The closure to run before performing a save operation.

## See Also

### Persisting unsaved changes

`var autosaveEnabled: Bool`

A Boolean value that indicates whether the context should automatically save any pending changes when certain events occur.

`func save() throws`

Writes any pending inserts, changes, and deletes to the persistent storage.

`func rollback()`

Discards pending inserts and deletes, restores changed models to their most recent committed state, and empties the undo stack.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/container

- SwiftData
- ModelContext
- container

Instance Property

# container

The context’s model container.

Swift 5.9+

var container: ModelContainer { get }

## Discussion

The property provides a reference to the model container you specify when calling the context’s initializer. For more information, see `init(_:)`.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/processpendingchanges()

#app-main)

- SwiftData
- ModelContext
- processPendingChanges()

Instance Method

# processPendingChanges()

Tells the undo manager to record any changes made to the context’s registered models.

Swift 5.9+

func processPendingChanges()

## Discussion

In AppKit-based applications, the system invokes this method at the end of each event loop. The framework may call it more frequently if it needs to coalesce your changes before continuing. You can also invoke it manually to coalesce any pending changes.

## See Also

### Performing undo and redo

`var undoManager: UndoManager?`

The object that provides undo support for the context.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/undomanager

- SwiftData
- ModelContext
- undoManager

Instance Property

# undoManager

The object that provides undo support for the context.

Swift 5.9+

var undoManager: UndoManager? { get set }

## Discussion

Assign an instance of `UndoManager` to this property to enable undo support for the context. The undo manager can be exclusive to the context, or an existing manager should you want to integrate this context’s undo operations with those of the rest of your app.

If the context does use an undo manager, improve performance by temporarily setting this property to `nil` when performing expensive operations, such as importing large numbers of models.

The default value is `nil`.

## See Also

### Performing undo and redo

`func processPendingChanges()`

Tells the undo manager to record any changes made to the context’s registered models.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/notificationkey

- SwiftData
- ModelContext
- ModelContext.NotificationKey

Enumeration

# ModelContext.NotificationKey

Describes the data in the user info dictionary of a notification sent by a model context.

Swift 5.9+

enum NotificationKey

## Topics

### Accessing notification keys

`case deletedIdentifiers`

A set of values identifying the context’s deleted models.

`case insertedIdentifiers`

A set of values identifying the context’s inserted models.

`case invalidatedAllIdentifiers`

A set of values identifying the context’s invalidated models.

`case updatedIdentifiers`

A set of values identifying the context’s updated models.

`case queryGeneration`

A token that indicates which generation of the model store SwiftData is using.

### Creating a notification key

`init?(rawValue: String)`

Creates a new instance with the specified raw value.

### Instance Properties

`var rawValue: String`

The corresponding value of the raw type.

### Type Aliases

`typealias RawValue`

The raw type that can be used to represent all values of the conforming type.

## Relationships

### Conforms To

- `Copyable`
- `Equatable`
- `Hashable`
- `RawRepresentable`

## See Also

### Registering for notifications

`static let willSave: Notification.Name`

A notification that posts when the context is about to process pending inserts, changes, and deletes.

`static let didSave: Notification.Name`

A notification that posts when the context finishes processing pending inserts, changes, and deletes.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/==(_:_:)

#app-main)

- SwiftData
- ModelContext
- ==(\_:\_:)

Operator

# ==(\_:\_:)

Returns a Boolean value indicating whether two values are equal.

Swift 5.9+

## Parameters

`lhs`

A value to compare.

`rhs`

Another value to compare.

## Discussion

Equality is the inverse of inequality. For any values `a` and `b`, `a == b` implies that `a != b` is `false`.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/debugdescription



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/author



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/editingstate

- SwiftData
- ModelContext
- editingState

Instance Property

# editingState

Swift 5.9+

var editingState: EditingState

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/deletehistory(_:)

#app-main)

- SwiftData
- ModelContext
- deleteHistory(\_:)

Instance Method

# deleteHistory(\_:)

Swift 5.9+

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/equatable-implementations

Collection

- SwiftData
- ModelContext
- Equatable Implementations

API Collection

# Equatable Implementations

## Topics

### Operators

Returns a Boolean value indicating whether two values are not equal.

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/save()).



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/autosaveenabled).



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/insert(_:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/delete(_:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/delete(model:where:includesubclasses:)).

).#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/haschanges)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/rollback())



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetch(_:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetch(_:batchsize:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetchcount(_:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetchidentifiers(_:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetchidentifiers(_:batchsize:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/willsave)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/didsave)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/init(_:))



---

# https://developer.apple.com/documentation/swiftdata/fetchresultscollection)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/enumerate(_:batchsize:allowescapingmutations:block:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/model(for:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/registeredmodel(for:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/insertedmodelsarray)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/changedmodelsarray)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/deletedmodelsarray)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/delete(model:where:includesubclasses:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/autosaveenabled)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/save())



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/transaction(block:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/container)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/processpendingchanges())

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/modelcontext/undomanager)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/notificationkey)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/==(_:_:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/debugdescription)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/author)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/editingstate)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/deletehistory(_:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/fetchhistory(_:))



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/equatable-implementations)



---

# https://developer.apple.com/documentation/swiftdata/BucketListItem



---

# https://developer.apple.com/documentation/swiftdata/Animal



---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/unique

- SwiftData
- Schema
- Schema.Attribute
- Schema.Attribute.Option
- unique

Type Property

# unique

Ensures the property’s value is unique across all models of the same type.

Swift 5.9+

static var unique: Schema.Attribute.Option { get }

## Mentioned in

Syncing model data across a person’s devices

## See Also

### Accessing property options

`static var allowsCloudEncryption: Schema.Attribute.Option`

Stores the property’s value in an encrypted form.

`static var externalStorage: Schema.Attribute.Option`

Stores the property’s value as binary data adjacent to the model storage.

`static var preserveValueOnDeletion: Schema.Attribute.Option`

Preserves the property’s value in the persistent history when the context deletes the owning model.

`static var spotlight: Schema.Attribute.Option`

Indexes the property’s value so it can appear in Spotlight search results.

Transforms the property’s value between an in-memory form and a persisted form.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/unique).



---

# https://developer.apple.com/documentation/swiftdata/modelconfiguration

- SwiftData
- ModelConfiguration

Structure

# ModelConfiguration

A type that describes the configuration of an app’s schema or specific group of models.

Swift 5.9+

struct ModelConfiguration

## Mentioned in

Syncing model data across a person’s devices

Preserving your app’s model data across launches

## Topics

### Creating a model configuration

`init(isStoredInMemoryOnly: Bool)`

Creates a basic model configuration.

`init(for: any PersistentModel.Type..., isStoredInMemoryOnly: Bool)`

Creates a model configuration for the specified model types.

`init(String?, schema: Schema?, isStoredInMemoryOnly: Bool, allowsSave: Bool, groupContainer: ModelConfiguration.GroupContainer, cloudKitDatabase: ModelConfiguration.CloudKitDatabase)`

Creates a named model configuration for the specified schema.

`init(String?, schema: Schema?, url: URL, allowsSave: Bool, cloudKitDatabase: ModelConfiguration.CloudKitDatabase)`

Creates a named model configuration that specifies the on-disk location of the schema’s persistent storage.

### Accessing configuration details

`let url: URL`

The on-disk location of the schema’s persistent storage.

`let name: String`

The model configuration’s name.

`let allowsSave: Bool`

A Boolean value that determines whether the associated persistent storage is writable.

`let isStoredInMemoryOnly: Bool`

A Boolean value that determines whether the associated persistent storage is ephemeral and exists only in memory.

### Managing schema information

`var schema: Schema?`

The schema that maps model classes to the associated data in the persistent storage.

`var id: URL`

The stable identity of the entity associated with this instance.

`typealias ID`

A type representing the stable identity of the entity associated with an instance.

### Sharing and syncing the model store

`let cloudKitContainerIdentifier: String?`

The identifier of the configuration’s CloudKit database container.

`let cloudKitDatabase: ModelConfiguration.CloudKitDatabase`

The option to use when detecting the container of the preferred CloudKit database.

`struct CloudKitDatabase`

A type that describes the options for detecting a CloudKit database.

`let groupAppContainerIdentifier: String?`

The identifier of the configuration’s app group container.

`let groupContainer: ModelConfiguration.GroupContainer`

The option to use when detecting the preferred app group container.

`struct GroupContainer`

A type that describes the options for detecting an app group container.

### Hashing

`func hash(into: inout Hasher)`

Hashes the essential components of this value by feeding them into the given hasher.

`var hashValue: Int`

The hash value.

### Comparing model configurations

Returns a Boolean value indicating whether two values are equal.

## Relationships

### Conforms To

- `Copyable`
- `CustomDebugStringConvertible`
- `DataStoreConfiguration`
- `Equatable`
- `Hashable`
- `Identifiable`

## See Also

### Creating a model container

[`init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: [ModelConfiguration]) throws`](https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:migrationplan:configurations:)-1czix)

Creates a model container using the specified schema, migration plan, and configurations.

`convenience init(for: any PersistentModel.Type..., migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified model types, migration plan, and zero or more configurations.

`convenience init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified schema, migration plan, and zero or more configurations.

`protocol PersistentModel`

An interface that enables SwiftData to manage a Swift class as a stored model.

`class Schema`

An object that maps model classes to data in the model store, and helps with the migration of that data between releases.

`protocol SchemaMigrationPlan`

An interface for describing the evolution of a schema and how to migrate between specific versions.

---

# https://developer.apple.com/documentation/swiftdata/modelconfiguration)



---

# https://developer.apple.com/documentation/swiftdata/modelcontext).



---

# https://developer.apple.com/documentation/swiftdata/modelactor()

#app-main)

- SwiftData
- ModelActor()

Macro

# ModelActor()

Converts a Swift actor into a model actor by generating boilerplate code that fulfills the requirements of the associated protocol.

Swift 5.9+

@attached(member, names: named(modelExecutor), named(modelContainer), named(init)) @attached(extension, conformances: ModelActor) macro ModelActor()

## See Also

### Model actors

`protocol ModelActor`

An interface for providing mutually-exclusive access to the attributes of a conforming model.

---

# https://developer.apple.com/documentation/swiftdata/modelactor

- SwiftData
- ModelActor

Protocol

# ModelActor

An interface for providing mutually-exclusive access to the attributes of a conforming model.

Swift 5.9+

protocol ModelActor : Actor

## Topics

### Accessing the container and context

`var modelContainer: ModelContainer`

The ModelContainer for the ModelActor The container that manages the app’s schema and model storage configuration

**Required**

`var modelContext: ModelContext`

The context that serializes any code running on the model actor.

### Accessing the executors

`var modelExecutor: any ModelExecutor`

The executor that coordinates access to the model actor.

`var unownedExecutor: UnownedSerialExecutor`

The optimized, unonwned reference to the model actor’s executor.

### Accessing specific models

Returns the model for the specified identifier, downcast to the appropriate class.

## Relationships

### Inherits From

- `Actor`
- `Sendable`
- `SendableMetatype`

## See Also

### Model actors

`macro ModelActor()`

Converts a Swift actor into a model actor by generating boilerplate code that fulfills the requirements of the associated protocol.

---

# https://developer.apple.com/documentation/swiftdata/defaultserialmodelexecutor

- SwiftData
- DefaultSerialModelExecutor

Class

# DefaultSerialModelExecutor

An object that safely performs storage-related tasks using an isolated model context.

Swift 5.9+

class DefaultSerialModelExecutor

## Topics

### Creating a model executor

`init(modelContext: ModelContext)`

### Accessing the context

`let modelContext: ModelContext`

## Relationships

### Conforms To

- `Copyable`
- `Executor`
- `ModelExecutor`
- `Sendable`
- `SendableMetatype`
- `SerialExecutor`
- `SerialModelExecutor`

## See Also

### Model executors

`protocol SerialModelExecutor`

An interface for performing serial storage-related tasks using an isolated model context.

`protocol ModelExecutor`

An interface for performing storage-related tasks using an isolated model context.

---

# https://developer.apple.com/documentation/swiftdata/serialmodelexecutor

- SwiftData
- SerialModelExecutor

Protocol

# SerialModelExecutor

An interface for performing serial storage-related tasks using an isolated model context.

Swift 5.9+

protocol SerialModelExecutor : ModelExecutor, SerialExecutor

## Relationships

### Inherits From

- `Executor`
- `ModelExecutor`
- `Sendable`
- `SendableMetatype`
- `SerialExecutor`

### Conforming Types

- `DefaultSerialModelExecutor`

## See Also

### Model executors

`class DefaultSerialModelExecutor`

An object that safely performs storage-related tasks using an isolated model context.

`protocol ModelExecutor`

An interface for performing storage-related tasks using an isolated model context.

---

# https://developer.apple.com/documentation/swiftdata/modelexecutor

- SwiftData
- ModelExecutor

Protocol

# ModelExecutor

An interface for performing storage-related tasks using an isolated model context.

Swift 5.9+

protocol ModelExecutor : Executor

## Topics

### Accessing the context

`var modelContext: ModelContext`

**Required**

## Relationships

### Inherits From

- `Executor`
- `Sendable`
- `SendableMetatype`

### Inherited By

- `SerialModelExecutor`

### Conforming Types

- `DefaultSerialModelExecutor`

## See Also

### Model executors

`class DefaultSerialModelExecutor`

An object that safely performs storage-related tasks using an isolated model context.

`protocol SerialModelExecutor`

An interface for performing serial storage-related tasks using an isolated model context.

---

# https://developer.apple.com/documentation/swiftdata/modelactor())



---

# https://developer.apple.com/documentation/swiftdata/modelactor)



---

# https://developer.apple.com/documentation/swiftdata/defaultserialmodelexecutor)



---

# https://developer.apple.com/documentation/swiftdata/serialmodelexecutor)



---

# https://developer.apple.com/documentation/swiftdata/modelexecutor)



---

# https://developer.apple.com/documentation/swiftdata/persistentmodel/persistentmodelid

- SwiftData
- PersistentModel
- persistentModelID

Instance Property

# persistentModelID

Swift 5.9+

var persistentModelID: PersistentIdentifier { get }

## Mentioned in

Fetching and filtering time-based model changes

## See Also

### Identifying the model instance

`struct PersistentIdentifier`

A type that describes the aggregate identity of a SwiftData model.

`var modelContext: ModelContext?`

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/preservevalueondeletion



---

# https://developer.apple.com/documentation/swiftdata/persistentmodel/persistentmodelid)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/preservevalueondeletion)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/cascade



---

# https://developer.apple.com/documentation/swiftdata/adding-and-editing-persistent-data-in-your-app).

.#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/cascade)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/nullify)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/historydescriptor/init(predicate:)

#app-main)

- SwiftData
- HistoryDescriptor
- init(predicate:)

Initializer

# init(predicate:)

Initializes a new history descriptor with the provided predicate.

Swift 5.9+

## See Also

### Creating a descriptor

Initializes a new history descriptor with the provided predicate and sort descriptor.

---

# https://developer.apple.com/documentation/swiftdata/historydescriptor/fetchlimit

- SwiftData
- HistoryDescriptor
- fetchLimit

Instance Property

# fetchLimit

The maximum number of transactions to retrieve from the model store’s history.

Swift 5.9+

var fetchLimit: UInt64

## Discussion

The default value is `nil`.

## See Also

### Getting the descriptor configuration

The predicate used to initialize the history descriptor.

The sort descriptor to use to sort the returned history data.

---

# https://developer.apple.com/documentation/swiftdata/historydescriptor/predicate

- SwiftData
- HistoryDescriptor
- predicate

Instance Property

# predicate

The predicate used to initialize the history descriptor.

Swift 5.9+

## See Also

### Getting the descriptor configuration

`var fetchLimit: UInt64`

The maximum number of transactions to retrieve from the model store’s history.

The sort descriptor to use to sort the returned history data.

---

# https://developer.apple.com/documentation/swiftdata/historydescriptor/init(predicate:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/historydescriptor/init(predicate:sortby:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/historydescriptor/fetchlimit)



---

# https://developer.apple.com/documentation/swiftdata/historydescriptor/predicate)



---

# https://developer.apple.com/documentation/swiftdata/historydescriptor/sortby)



---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/maincontext



---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/maincontext)



---

# https://developer.apple.com/documentation/swiftdata/modelcontainer).



---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/deletealldata()



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/delete(_:)).



---

# https://developer.apple.com/documentation/swiftdata/modelcontext/save());



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum).)



---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/deletealldata()).



---

# https://developer.apple.com/documentation/swiftdata/schemamigrationplan

- SwiftData
- SchemaMigrationPlan

Protocol

# SchemaMigrationPlan

An interface for describing the evolution of a schema and how to migrate between specific versions.

Swift 5.9+

protocol SchemaMigrationPlan

## Topics

### Managing versioned schemas

[`static var schemas: [any VersionedSchema.Type]`](https://developer.apple.com/documentation/swiftdata/schemamigrationplan/schemas)

**Required**

`protocol VersionedSchema`

An interface for describing a specific version of a schema, including the models it contains.

### Managing migration stages

[`static var stages: [MigrationStage]`](https://developer.apple.com/documentation/swiftdata/schemamigrationplan/stages)

`enum MigrationStage`

Describes a migration between two versions of the same schema.

## See Also

### Creating a model container

[`init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: [ModelConfiguration]) throws`](https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:migrationplan:configurations:)-1czix)

Creates a model container using the specified schema, migration plan, and configurations.

`convenience init(for: any PersistentModel.Type..., migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified model types, migration plan, and zero or more configurations.

`convenience init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified schema, migration plan, and zero or more configurations.

`protocol PersistentModel`

An interface that enables SwiftData to manage a Swift class as a stored model.

`struct ModelConfiguration`

A type that describes the configuration of an app’s schema or specific group of models.

`class Schema`

An object that maps model classes to data in the model store, and helps with the migration of that data between releases.

---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:migrationplan:configurations:)-8s4ts

-8s4ts#app-main)

- SwiftData
- ModelContainer
- init(for:migrationPlan:configurations:)

Initializer

# init(for:migrationPlan:configurations:)

Creates a model container using the specified model types, migration plan, and zero or more configurations.

Swift 5.9+

convenience init(
for forTypes: any PersistentModel.Type...,
migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
configurations: ModelConfiguration...
) throws

## Parameters

`forTypes`

A list of the persistent model types that comprise your app’s schema.

`migrationPlan`

A plan that describes the evolution of your app’s schema and how the container migrates between specific versions. For more information, see `SchemaMigrationPlan`.

`configurations`

A list configurations that describe how the container manages the persisted data for specific groups of models. For more information, see `ModelConfiguration`.

## Discussion

## See Also

### Creating a model container

[`init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: [ModelConfiguration]) throws`](https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:migrationplan:configurations:)-1czix)

Creates a model container using the specified schema, migration plan, and configurations.

`convenience init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified schema, migration plan, and zero or more configurations.

`protocol PersistentModel`

An interface that enables SwiftData to manage a Swift class as a stored model.

`struct ModelConfiguration`

A type that describes the configuration of an app’s schema or specific group of models.

`class Schema`

An object that maps model classes to data in the model store, and helps with the migration of that data between releases.

`protocol SchemaMigrationPlan`

An interface for describing the evolution of a schema and how to migrate between specific versions.

---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:migrationplan:configurations:)-qof9

-qof9#app-main)

- SwiftData
- ModelContainer
- init(for:migrationPlan:configurations:)

Initializer

# init(for:migrationPlan:configurations:)

Creates a model container using the specified schema, migration plan, and zero or more configurations.

Swift 5.9+

convenience init(
for givenSchema: Schema,
migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
configurations: ModelConfiguration...
) throws

## Parameters

`givenSchema`

A schema that maps your app’s model classes to the associated data in the app’s persistent storage. For more information, see `Schema`.

`migrationPlan`

A plan that describes the evolution of your app’s schema and how the container migrates between specific versions. For more information, see `SchemaMigrationPlan`.

`configurations`

A list of configurations that describe how the container manages the persisted data for specific groups of models. For more information, see `ModelConfiguration`.

## Discussion

## See Also

### Creating a model container

[`init(for: Schema, migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: [ModelConfiguration]) throws`](https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:migrationplan:configurations:)-1czix)

Creates a model container using the specified schema, migration plan, and configurations.

`convenience init(for: any PersistentModel.Type..., migrationPlan: (any SchemaMigrationPlan.Type)?, configurations: ModelConfiguration...) throws`

Creates a model container using the specified model types, migration plan, and zero or more configurations.

`protocol PersistentModel`

An interface that enables SwiftData to manage a Swift class as a stored model.

`struct ModelConfiguration`

A type that describes the configuration of an app’s schema or specific group of models.

`class Schema`

An object that maps model classes to data in the model store, and helps with the migration of that data between releases.

`protocol SchemaMigrationPlan`

An interface for describing the evolution of a schema and how to migrate between specific versions.

---

# https://developer.apple.com/documentation/swiftdata/schema



---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/schema

- SwiftData
- ModelContainer
- schema

Instance Property

# schema

The schema that maps your app’s model classes to the associated data in the app’s persistent storage.

Swift 5.9+

final let schema: Schema

## Discussion

This property provides a reference to the schema you specified when calling one the container’s initializers.

## See Also

### Managing schema and configuration details

The configurations that describe how to manage the persisted data for specific groups of models.

`let migrationPlan: (any SchemaMigrationPlan.Type)?`

The plan that describes the evolution of your app’s schema and how to migrate between specific versions.

---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/configurations

- SwiftData
- ModelContainer
- configurations

Instance Property

# configurations

The configurations that describe how to manage the persisted data for specific groups of models.

Swift 5.9+

## Discussion

Use this property to access or update the configurations that the container uses to manage model data. The default value is the set of configurations you specified when calling one of the container’s initializers.

## See Also

### Managing schema and configuration details

`let schema: Schema`

The schema that maps your app’s model classes to the associated data in the app’s persistent storage.

`let migrationPlan: (any SchemaMigrationPlan.Type)?`

The plan that describes the evolution of your app’s schema and how to migrate between specific versions.

---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/migrationplan

- SwiftData
- ModelContainer
- migrationPlan

Instance Property

# migrationPlan

The plan that describes the evolution of your app’s schema and how to migrate between specific versions.

Swift 5.9+

final let migrationPlan: (any SchemaMigrationPlan.Type)?

## Discussion

This property provides a reference to the migration plan you specified when calling one the container’s initializers. If you didn’t specify one, the property’s value is `nil`.

## See Also

### Managing schema and configuration details

`let schema: Schema`

The schema that maps your app’s model classes to the associated data in the app’s persistent storage.

The configurations that describe how to manage the persisted data for specific groups of models.

---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/==(_:_:)

#app-main)

- SwiftData
- ModelContainer
- ==(\_:\_:)

Operator

# ==(\_:\_:)

Returns a Boolean value indicating whether two values are equal.

Swift 5.9+

## Parameters

`lhs`

A value to compare.

`rhs`

Another value to compare.

## Discussion

Equality is the inverse of inequality. For any values `a` and `b`, `a == b` implies that `a != b` is `false`.

---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/init(for:configurations:)-621ei

-621ei#app-main)

- SwiftData
- ModelContainer
- init(for:configurations:)

Initializer

# init(for:configurations:)

Swift 5.9+

convenience init(
for forTypes: any PersistentModel.Type...,
configurations: any DataStoreConfiguration...
) throws

---

# https://developer.apple.com/documentation/swiftdata/modelcontainer/erase()



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/==(_:_:)

#app-main)

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.Option
- ==(\_:\_:)

Operator

# ==(\_:\_:)

Returns a Boolean value indicating whether two values are equal.

Swift 5.9+

## Parameters

`lhs`

A value to compare.

`rhs`

Another value to compare.

## Discussion

Equality is the inverse of inequality. For any values `a` and `b`, `a == b` implies that `a != b` is `false`.

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/init(from:)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/debugdescription

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.Option
- debugDescription

Instance Property

# debugDescription

A textual representation of this instance, suitable for debugging.

Swift 5.9+

var debugDescription: String { get }

## Discussion

Calling this property directly is discouraged. Instead, convert an instance of any type to a string by using the `String(reflecting:)` initializer. This initializer works with any type, and uses the custom `debugDescription` property for types that conform to `CustomDebugStringConvertible`:

struct Point: CustomDebugStringConvertible {
let x: Int, y: Int

var debugDescription: String {
return "(\(x), \(y))"
}
}

let p = Point(x: 21, y: 30)
let s = String(reflecting: p)
print(s)
// Prints "(21, 30)"

The conversion of `p` to a string in the assignment to `s` uses the `Point` type’s `debugDescription` property.

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/hashvalue

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.Option
- hashValue

Instance Property

# hashValue

The hash value.

Swift 5.9+

var hashValue: Int { get }

## Discussion

Hash values are not guaranteed to be equal across different executions of your program. Do not save hash values to use during a future execution.

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/encode(to:)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/hash(into:)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/unique



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/equatable-implementations

Collection

- SwiftData
- ModelContainer
- Schema
- ModelContainer
- Schema
- Schema components
- Schema.Relationship
- Schema.Relationship.Option
- Equatable Implementations

API Collection

# Equatable Implementations

## Topics

### Operators

Returns a Boolean value indicating whether two values are not equal.

---

# https://developer.apple.com/documentation/swiftdata/schema)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/==(_:_:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/init(from:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/debugdescription)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/hashvalue)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/encode(to:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/hash(into:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/unique)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/option/equatable-implementations)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/deny

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.DeleteRule
- Schema.Relationship.DeleteRule.deny

Case

# Schema.Relationship.DeleteRule.deny

A rule that prevents the deletion of a model because it contains one or more references to other models.

Swift 5.9+

case deny

## Mentioned in

Syncing model data across a person’s devices

## See Also

### Accessing delete rules

`case cascade`

A rule that deletes any related models.

`case noAction`

A rule that doesn’t make changes to any related models.

`case nullify`

A rule that nullifies the related model’s reference to the deleted model.

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/noaction

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.DeleteRule
- Schema.Relationship.DeleteRule.noAction

Case

# Schema.Relationship.DeleteRule.noAction

A rule that doesn’t make changes to any related models.

Swift 5.9+

case noAction

## Discussion

Ensure that you take the appropriate action on any related models when using this delete rule, such as deleting them or nullifying their references to the deleted model. Otherwise, your data will be in an inconsistent state and may reference models that don’t exist.

## See Also

### Accessing delete rules

`case cascade`

A rule that deletes any related models.

`case deny`

A rule that prevents the deletion of a model because it contains one or more references to other models.

`case nullify`

A rule that nullifies the related model’s reference to the deleted model.

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/init(rawvalue:)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/rawvalue-swift.property

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.DeleteRule
- rawValue

Instance Property

# rawValue

The corresponding value of the raw type.

Swift 5.9+

var rawValue: String { get }

## Discussion

A new instance initialized with `rawValue` will be equivalent to this instance. For example:

enum PaperSize: String {
case A4, A5, Letter, Legal
}

let selectedSize = PaperSize.Letter
print(selectedSize.rawValue)
// Prints "Letter"

print(selectedSize == PaperSize(rawValue: selectedSize.rawValue)!)
// Prints "true"

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/rawvalue-swift.typealias

- SwiftData
- Schema
- Schema.Relationship
- Schema.Relationship.DeleteRule
- Schema.Relationship.DeleteRule.RawValue

Type Alias

# Schema.Relationship.DeleteRule.RawValue

The raw type that can be used to represent all values of the conforming type.

Swift 5.9+

typealias RawValue = String

## Discussion

Every distinct value of the conforming type has a corresponding unique value of the `RawValue` type, but there may be values of the `RawValue` type that don’t have a corresponding value of the conforming type.

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/equatable-implementations

Collection

- SwiftData
- ModelContainer
- Schema
- ModelContainer
- Schema
- Schema components
- Schema.Relationship
- Schema.Relationship.DeleteRule
- Equatable Implementations

API Collection

# Equatable Implementations

## Topics

### Operators

Returns a Boolean value indicating whether two values are not equal.

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/rawrepresentable-implementations

Collection

- SwiftData
- ModelContainer
- Schema
- ModelContainer
- Schema
- Schema components
- Schema.Relationship
- Schema.Relationship.DeleteRule
- RawRepresentable Implementations

API Collection

# RawRepresentable Implementations

## Topics

### Initializers

`init(from: any Decoder) throws`

Creates a new instance by decoding from the given decoder, when the type’s `RawValue` is `String`.

### Instance Properties

`var hashValue: Int`

### Instance Methods

`func encode(to: any Encoder) throws`

Encodes this value into the given encoder, when the type’s `RawValue` is `String`.

`func hash(into: inout Hasher)`

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/keypath

- SwiftData
- Schema
- Schema.Relationship
- keypath

Instance Property

# keypath

Swift 5.9+

final var keypath: AnyKeyPath?

## See Also

### Managing the configuration

`var destination: String`

`var inverseName: String?`

`var inverseKeyPath: AnyKeyPath?`

`var deleteRule: Schema.Relationship.DeleteRule`

`enum DeleteRule`

Describes the rule to apply when deleting a model containing references to other models.

`var isToOneRelationship: Bool`

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/destination

- SwiftData
- Schema
- Schema.Relationship
- destination

Instance Property

# destination

Swift 5.9+

final var destination: String

## See Also

### Managing the configuration

`var keypath: AnyKeyPath?`

`var inverseName: String?`

`var inverseKeyPath: AnyKeyPath?`

`var deleteRule: Schema.Relationship.DeleteRule`

`enum DeleteRule`

Describes the rule to apply when deleting a model containing references to other models.

`var isToOneRelationship: Bool`

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/inversename

- SwiftData
- Schema
- Schema.Relationship
- inverseName

Instance Property

# inverseName

Swift 5.9+

final var inverseName: String?

## See Also

### Managing the configuration

`var keypath: AnyKeyPath?`

`var destination: String`

`var inverseKeyPath: AnyKeyPath?`

`var deleteRule: Schema.Relationship.DeleteRule`

`enum DeleteRule`

Describes the rule to apply when deleting a model containing references to other models.

`var isToOneRelationship: Bool`

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/inversekeypath



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.property

- SwiftData
- Schema
- Schema.Relationship
- deleteRule

Instance Property

# deleteRule

Swift 5.9+

final var deleteRule: Schema.Relationship.DeleteRule

## See Also

### Managing the configuration

`var keypath: AnyKeyPath?`

`var destination: String`

`var inverseName: String?`

`var inverseKeyPath: AnyKeyPath?`

`enum DeleteRule`

Describes the rule to apply when deleting a model containing references to other models.

`var isToOneRelationship: Bool`

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/istoonerelationship

- SwiftData
- Schema
- Schema.Relationship
- isToOneRelationship

Instance Property

# isToOneRelationship

Swift 5.9+

final var isToOneRelationship: Bool { get }

## See Also

### Managing the configuration

`var keypath: AnyKeyPath?`

`var destination: String`

`var inverseName: String?`

`var inverseKeyPath: AnyKeyPath?`

`var deleteRule: Schema.Relationship.DeleteRule`

`enum DeleteRule`

Describes the rule to apply when deleting a model containing references to other models.

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/deny)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/noaction)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/init(rawvalue:))

)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/rawvalue-swift.property)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/rawvalue-swift.typealias)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/equatable-implementations)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum/rawrepresentable-implementations)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/keypath)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/destination)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/inversename)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/inversekeypath)



---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.property)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/istoonerelationship)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/relationship/deleterule-swift.enum)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute

- SwiftData
- Schema
- Schema.Attribute

Class

# Schema.Attribute

An object that describes the configuration and behavior of a specific property of a model class.

Swift 5.9+

class Attribute

## Topics

### Creating an attribute

`init(Schema.Attribute.Option..., originalName: String?, hashModifier: String?)`

[`init(name: String, originalName: String?, options: [Schema.Attribute.Option], valueType: any Any.Type, defaultValue: Any?, hashModifier: String?)`](https://developer.apple.com/documentation/swiftdata/schema/attribute/init(name:originalname:options:valuetype:defaultvalue:hashmodifier:))

### Specifying value information

`var defaultValue: Any?`

`var valueType: any Any.Type`

### Managing identity

`var name: String`

`var originalName: String`

### Determining behavior

[`var options: [Schema.Attribute.Option]`](https://developer.apple.com/documentation/swiftdata/schema/attribute/options)

`var isAttribute: Bool`

`var isTransformable: Bool`

### Versioning

`var hashModifier: String?`

### Encoding and decoding

`func encode(to: any Encoder) throws`

Encodes this value into the given encoder.

`init(from: any Decoder) throws`

Creates a new instance by decoding from the given decoder.

### Hashing

`func hash(into: inout Hasher)`

Hashes the essential components of this value by feeding them into the given hasher.

### Comparing attributes

Returns a Boolean value indicating whether two values are equal.

### Debugging

`var debugDescription: String`

A textual representation of this instance, suitable for debugging.

### Structures

`struct Option`

### Instance Properties

`var hashValue: Int`

The hash value.

`var isOptional: Bool`

`var isRelationship: Bool`

`var isTransient: Bool`

`var isUnique: Bool`

## Relationships

### Inherited By

- `Schema.CompositeAttribute`

### Conforms To

- `CustomDebugStringConvertible`
- `Decodable`
- `Encodable`
- `Equatable`
- `Hashable`
- `SchemaProperty`

## See Also

### Attributes

`class CompositeAttribute`

An object that describes an attribute that derives its value by composing other attributes.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/allowscloudencryption

- SwiftData
- Schema
- Schema.Attribute
- Schema.Attribute.Option
- allowsCloudEncryption

Type Property

# allowsCloudEncryption

Stores the property’s value in an encrypted form.

Swift 5.9+

static var allowsCloudEncryption: Schema.Attribute.Option { get }

## See Also

### Accessing property options

`static var externalStorage: Schema.Attribute.Option`

Stores the property’s value as binary data adjacent to the model storage.

`static var preserveValueOnDeletion: Schema.Attribute.Option`

Preserves the property’s value in the persistent history when the context deletes the owning model.

`static var spotlight: Schema.Attribute.Option`

Indexes the property’s value so it can appear in Spotlight search results.

`static var unique: Schema.Attribute.Option`

Ensures the property’s value is unique across all models of the same type.

Transforms the property’s value between an in-memory form and a persisted form.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/externalstorage

- SwiftData
- Schema
- Schema.Attribute
- Schema.Attribute.Option
- externalStorage

Type Property

# externalStorage

Stores the property’s value as binary data adjacent to the model storage.

Swift 5.9+

static var externalStorage: Schema.Attribute.Option { get }

## See Also

### Accessing property options

`static var allowsCloudEncryption: Schema.Attribute.Option`

Stores the property’s value in an encrypted form.

`static var preserveValueOnDeletion: Schema.Attribute.Option`

Preserves the property’s value in the persistent history when the context deletes the owning model.

`static var spotlight: Schema.Attribute.Option`

Indexes the property’s value so it can appear in Spotlight search results.

`static var unique: Schema.Attribute.Option`

Ensures the property’s value is unique across all models of the same type.

Transforms the property’s value between an in-memory form and a persisted form.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/spotlight

- SwiftData
- Schema
- Schema.Attribute
- Schema.Attribute.Option
- spotlight

Type Property

# spotlight

Indexes the property’s value so it can appear in Spotlight search results.

Swift 5.9+

static var spotlight: Schema.Attribute.Option { get }

## See Also

### Accessing property options

`static var allowsCloudEncryption: Schema.Attribute.Option`

Stores the property’s value in an encrypted form.

`static var externalStorage: Schema.Attribute.Option`

Stores the property’s value as binary data adjacent to the model storage.

`static var preserveValueOnDeletion: Schema.Attribute.Option`

Preserves the property’s value in the persistent history when the context deletes the owning model.

`static var unique: Schema.Attribute.Option`

Ensures the property’s value is unique across all models of the same type.

Transforms the property’s value between an in-memory form and a persisted form.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/transformable(by:)-9d4xh



---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/transformable(by:)-lunz

-lunz#app-main)

- SwiftData
- Schema
- Schema.Attribute
- Schema.Attribute.Option
- transformable(by:)

Type Method

# transformable(by:)

Swift 5.9+

## See Also

### Accessing property options

`static var allowsCloudEncryption: Schema.Attribute.Option`

Stores the property’s value in an encrypted form.

`static var externalStorage: Schema.Attribute.Option`

Stores the property’s value as binary data adjacent to the model storage.

`static var preserveValueOnDeletion: Schema.Attribute.Option`

Preserves the property’s value in the persistent history when the context deletes the owning model.

`static var spotlight: Schema.Attribute.Option`

Indexes the property’s value so it can appear in Spotlight search results.

`static var unique: Schema.Attribute.Option`

Ensures the property’s value is unique across all models of the same type.

Transforms the property’s value between an in-memory form and a persisted form.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/ephemeral



---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/customdebugstringconvertible-implementations

Collection

- SwiftData
- ModelContainer
- Schema
- ModelContainer
- Schema
- Schema components
- Schema.Attribute
- Schema.Attribute.Option
- CustomDebugStringConvertible Implementations

API Collection

# CustomDebugStringConvertible Implementations

## Topics

### Instance Properties

`var debugDescription: String`

A textual representation of this instance, suitable for debugging.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/decodable-implementations

Collection

- SwiftData
- ModelContainer
- Schema
- ModelContainer
- Schema
- Schema components
- Schema.Attribute
- Schema.Attribute.Option
- Decodable Implementations

API Collection

# Decodable Implementations

## Topics

### Initializers

`init(from: any Decoder) throws`

Creates a new instance by decoding from the given decoder.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/encodable-implementations

Collection

- SwiftData
- ModelContainer
- Schema
- ModelContainer
- Schema
- Schema components
- Schema.Attribute
- Schema.Attribute.Option
- Encodable Implementations

API Collection

# Encodable Implementations

## Topics

### Instance Methods

`func encode(to: any Encoder) throws`

Encodes this value into the given encoder.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/equatable-implementations

Collection

- SwiftData
- ModelContainer
- Schema
- ModelContainer
- Schema
- Schema components
- Schema.Attribute
- Schema.Attribute.Option
- Equatable Implementations

API Collection

# Equatable Implementations

## Topics

### Operators

Returns a Boolean value indicating whether two values are not equal.

Returns a Boolean value indicating whether two values are equal.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/hashable-implementations

Collection

- SwiftData
- ModelContainer
- Schema
- ModelContainer
- Schema
- Schema components
- Schema.Attribute
- Schema.Attribute.Option
- Hashable Implementations

API Collection

# Hashable Implementations

## Topics

### Instance Properties

`var hashValue: Int`

The hash value.

### Instance Methods

`func hash(into: inout Hasher)`

Hashes the essential components of this value by feeding them into the given hasher.

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute)



---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/allowscloudencryption)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/externalstorage)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/spotlight)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/unique)



---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/transformable(by:)-9d4xh)

-9d4xh)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/transformable(by:)-lunz)

-lunz)#app-main)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/ephemeral)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/customdebugstringconvertible-implementations)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/decodable-implementations)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/encodable-implementations)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/equatable-implementations)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

# https://developer.apple.com/documentation/swiftdata/schema/attribute/option/hashable-implementations)

# The page you're looking for can't be found.

Search developer.apple.comSearch Icon

---

