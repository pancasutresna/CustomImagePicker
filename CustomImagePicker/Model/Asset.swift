//
//  Asset.swift
//  CustomImagePicker
//
//  Created by I Gede Panca Sutresna on 23/04/24.
//

import SwiftUI
import Photos

struct Asset: Identifiable {
    var id = UUID().uuidString
    var asset: PHAsset
    var image: UIImage
}
