//
//  SingleImagePicker.swift
//  DairoMUSIC-IOS
//
//  Created by zhoulq on 2026/11/07.
//

import SwiftUI
import PhotosUI
import DairoUI_IOS

/**
 系统图片选择器,只能选一张,不需要相册权限
 */
struct SingleImagePicker: UIViewControllerRepresentable {
    
    @Binding var isPresented: Bool
    
    ///选择图片之后的回调,在主线程
    let onPick: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: SingleImagePicker
        
        init(_ parent: SingleImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            self.parent.isPresented = false
            guard let provider = results.first?.itemProvider else{
                return
            }
            let onPick = self.parent.onPick
            provider.loadObject(ofClass: UIImage.self){ object, _ in
                DispatchQueue.main.async {
                    guard let image = object as? UIImage else{
                        Toast.show("读取图片失败")
                        return
                    }
                    onPick(image)
                }
            }
        }
    }
}
