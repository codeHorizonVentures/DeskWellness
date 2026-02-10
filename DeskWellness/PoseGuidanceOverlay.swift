
//
//  PoseGuidanceOverlay.swift
//  DeskWellness
//
//  Created by Petro Kulakov on 09.02.2026.
//

import SwiftUI

struct PoseGuidanceOverlay: View {
    let imageName: String
    let opacity: Double
    
    init(imageName: String, opacity: Double = 0.6) {
        self.imageName = imageName
        self.opacity = opacity
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed background to make the white silhouette pop
                Color.black.opacity(0.1)
                
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    // Invert black asset to white
                    .colorInvert()
                    .opacity(opacity)
                    // Add a drop shadow for visibility on light backgrounds
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .opacity(isAnimating ? opacity : opacity * 0.8)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
            }
        }
        .allowsHitTesting(false) // Pass touches through to camera/buttons
    }
    
    @State private var isAnimating = false
}

#Preview {
    ZStack {
        Color.gray
        PoseGuidanceOverlay(imageName: "front-pose")
    }
}
