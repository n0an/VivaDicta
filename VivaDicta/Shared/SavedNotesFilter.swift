//
//  SavedNotesFilter.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import Foundation

struct SavedNotesFilter: Equatable {
    var sourceTags: Set<String> = []
    var userTagIds: Set<UUID> = []

    var isActive: Bool {
        !sourceTags.isEmpty || !userTagIds.isEmpty
    }
}

enum SavedNotesFilterStorage {
    static func load(userDefaults: UserDefaults = UserDefaultsStorage.appPrivate) -> SavedNotesFilter {
        let sourceTags = Set(userDefaults.stringArray(forKey: UserDefaultsStorage.Keys.savedNotesFilterSourceTags) ?? [])
        let userTagIds = Set(
            (userDefaults.stringArray(forKey: UserDefaultsStorage.Keys.savedNotesFilterUserTagIds) ?? [])
                .compactMap(UUID.init(uuidString:))
        )

        return SavedNotesFilter(sourceTags: sourceTags, userTagIds: userTagIds)
    }

    static func save(_ filter: SavedNotesFilter, userDefaults: UserDefaults = UserDefaultsStorage.appPrivate) {
        if filter.sourceTags.isEmpty {
            userDefaults.removeObject(forKey: UserDefaultsStorage.Keys.savedNotesFilterSourceTags)
        } else {
            userDefaults.set(filter.sourceTags.sorted(), forKey: UserDefaultsStorage.Keys.savedNotesFilterSourceTags)
        }

        if filter.userTagIds.isEmpty {
            userDefaults.removeObject(forKey: UserDefaultsStorage.Keys.savedNotesFilterUserTagIds)
        } else {
            userDefaults.set(
                filter.userTagIds.map(\.uuidString).sorted(),
                forKey: UserDefaultsStorage.Keys.savedNotesFilterUserTagIds
            )
        }
    }

    static func sanitize(
        _ filter: SavedNotesFilter,
        availableSourceTags: [String],
        availableUserTagIds: Set<UUID>
    ) -> SavedNotesFilter {
        SavedNotesFilter(
            sourceTags: filter.sourceTags.intersection(Set(availableSourceTags)),
            userTagIds: filter.userTagIds.intersection(availableUserTagIds)
        )
    }
}
