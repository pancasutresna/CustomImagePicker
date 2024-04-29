//
//  ImageViewModel.swift
//  CustomImagePicker
//
//  Created by I Gede Panca Sutresna on 19/04/24.
//

import SwiftUI
import Photos
import AVKit

class ImagePickerViewModel: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    
    @Published var showImagePicker = false
    
    @Published var library_status = LibraryStatus.denied
    
    // List of Fetched Photos...
    
    @Published var fetchedPhotos: [Asset] = []
    
    // To get updates....
    @Published var allPhotos : PHFetchResult<PHAsset>!
    
    // Preview....
    @Published var showPreview = false
    @Published var selectedImagePreview: UIImage!
    @Published var selectedVideoPreview: AVAsset!
    
    func openImagePicker() {
        
        // closing keyboard if opened
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Fetching images when it needed
        if (fetchedPhotos.isEmpty) {
            fetchPhotos()
        }
        
        withAnimation{
            showImagePicker.toggle()
        }
    }
    
    func setUp() {
        
        // requesting permission...
        PHPhotoLibrary.requestAuthorization(for: .readWrite) {[self] (status) in
            DispatchQueue.main.async {
                switch status {
                case .denied:
                    library_status = .denied
                case .authorized:
                    library_status = .approved
                case .limited:
                    library_status = .limited
                default:
                    library_status = .denied
                }
            }
        }
        
        // Registering Observer....
        PHPhotoLibrary.shared().register(self)
    }
    
    // Listening to changes
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard let _ = allPhotos else { return }
        
        if let updates = changeInstance.changeDetails(for: allPhotos) {
            // Getting Updated List....
            let updatedPhotos = updates.fetchResultAfterChanges
            
            // There is bug in it....
            // Its not updating the inserted or removed items....
            
            print(updates.insertedObjects.count)
            print(updates.removedObjects.count)
            
            // So were going to verify all and append only no in the list ....
            // to avoid of reloading all and ram usage ....
            
            updatedPhotos.enumerateObjects{[self](asset, index, _) in
                    
                if !allPhotos.contains(asset) {
                    // If its not there....
                    // getting image and appending it to array....
                    
                    getImageFromAsset(asset: asset, size: CGSize(width: 150, height: 150)) { (image) in
                        DispatchQueue.main.async {
                            fetchedPhotos.append(Asset(asset: asset, image: image))
                        }
                    }
                }
            }
            
            // To remove if image is removed....
            allPhotos.enumerateObjects { (asset, index, _) in
            
                if !updatedPhotos.contains(asset) {
                    
                    // removing it
                    DispatchQueue.main.async {
                        self.fetchedPhotos.removeAll { (result) -> Bool in
                            return result.asset == asset
                            
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.allPhotos = updatedPhotos
            }
            
        }
    }
    
    func fetchPhotos() {
        // Fetching all photos...
        
        let options = PHFetchOptions()
        options.sortDescriptors = [
            // Latest to Old...
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.includeHiddenAssets = false
        
        let fetchResult = PHAsset.fetchAssets(with: options)
        
        allPhotos = fetchResult
        
        fetchResult.enumerateObjects {[self] (asset, index, _) in
            
            // Getting Image From Asset...
            getImageFromAsset(asset: asset, size: CGSize(width: 150, height: 150)) {(image) in
            
                // Appending it To Array...
                
                // Why we storing asset..
                // to get full image for sending
                
                fetchedPhotos.append(Asset(asset: asset, image: image))
            }
        }
    }
    
    func getImageFromAsset(asset: PHAsset, size: CGSize, completion: @escaping (UIImage)->()) {
        
        // To cache image in memory...
        let imageManager = PHCachingImageManager()
        imageManager.allowsCachingHighQualityImages = true
        
        // Your Own Properties For Images...
        let imageOptions = PHImageRequestOptions()
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.isSynchronous = false
        
        // To reduce ram usage just getting thumbnail size of image...
        let size = CGSize(width: 150, height: 150)
        
        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: imageOptions) { (image, _) in
            
            guard let resizedImage = image else { return }
            
            completion(resizedImage)
        }
        
    }
    
    // Opening Image or Video
    func extractPreviewData(asset: PHAsset) {
        
        let manager = PHCachingImageManager()
        
        if asset.mediaType == .image {
            // Extract image....
            getImageFromAsset(asset: asset, size: PHImageManagerMaximumSize) { (image) in
                DispatchQueue.main.async {
                    self.selectedImagePreview = image
                }
            }
        }
        
        if asset.mediaType == .video {
            // Extract video....
            
            let videoManager = PHVideoRequestOptions()
            videoManager.deliveryMode = .highQualityFormat
            
            manager.requestAVAsset(forVideo: asset, options: videoManager) { (videoAsset, _, _) in
                
                guard let videoUrl = videoAsset else { return }
                
                DispatchQueue.main.async {
                    self.selectedVideoPreview = videoUrl
                }
            }
        }
    }
}
