//
//  UIImage+Extensions.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 07.02.2026.
//

import UIKit

extension UIImage {
    /// Resizes the image to the specified maximum dimension while preserving aspect ratio.
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // If image is already smaller, return self
        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
