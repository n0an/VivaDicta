//
//  SizeToFitModifier.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.05.29
//

import SwiftUI

/// A custom presentation detent that makes a sheet automatically size
/// itself to fit the height of its content.
///
/// Use it together with the ``SwiftUI/View/presentationDetents(_:additional:)``
/// modifier to opt a sheet into content-driven sizing:
///
/// ```swift
/// .sheet(isPresented: $isPresented) {
///     MySheet()
///         .presentationDetents(.sizeToFit)
/// }
/// ```
enum SizeToFitPresentationDetent {
    /// Size the sheet to fit the intrinsic height of its content.
    case sizeToFit
}

/// A modifier that observes the size of a sheet's content and applies the
/// measured height as a native `.height` presentation detent.
///
/// Any `additional` detents are unioned with the measured height, so the
/// sheet can still be resized to standard detents such as `.medium` or
/// `.large` when desired.
struct SizeToFitModifier: ViewModifier {
    let additional: Set<PresentationDetent>

    @State private var contentHeight = 0.0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                contentHeight = height
            }
            .presentationDetents(Set([.height(contentHeight)]).union(additional))
    }
}

extension View {
    /// Applies a content-fitting presentation detent to a sheet.
    ///
    /// The sheet measures its content and uses the resulting height as a
    /// native `.height` detent, so it sizes itself to fit. Pass `additional`
    /// detents to keep the sheet resizable to other heights:
    ///
    /// ```swift
    /// MySheet()
    ///     .presentationDetents(.sizeToFit, additional: [.medium, .large])
    /// ```
    ///
    /// - Parameters:
    ///   - detent: The custom ``SizeToFitPresentationDetent`` to apply.
    ///   - additional: Extra detents the sheet can also resize to.
    func presentationDetents(
        _ detent: SizeToFitPresentationDetent,
        additional: Set<PresentationDetent> = []
    ) -> some View {
        modifier(SizeToFitModifier(additional: additional))
    }
}
