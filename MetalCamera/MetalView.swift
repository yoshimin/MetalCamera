//
//  MetalView.swift
//  MetalCamera
//
//  Created by 新谷　よしみ on 2017/02/12.
//
//

import MetalKit
import MetalPerformanceShaders
import AVFoundation

class MetalView: MTKView {
    let semaphore = DispatchSemaphore(value: 3)
    
    var textureCache : CVMetalTextureCache?
    var imageTexture: MTLTexture?
    
    var commandQueue: MTLCommandQueue?
    var pipeline: MTLRenderPipelineState?
    var textureLoader: MTKTextureLoader?
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        device = MTLCreateSystemDefaultDevice()
        framebufferOnly = false
        autoResizeDrawable = false
        clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        textureLoader = MTKTextureLoader(device: device!)
        
        commandQueue = device?.makeCommandQueue()
        
        let library = device?.newDefaultLibrary()
        guard
            let vertex = library?.makeFunction(name: "mapTexture"),
            let fragment = library?.makeFunction(name: "displayTexture")
        else {
            fatalError()
        }
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.sampleCount = sampleCount
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        pipeline = try! device?.makeRenderPipelineState(descriptor: descriptor)
    }
    
    public func setPixelBuffer(_ buffer: CVPixelBuffer) {
        // @see http://qiita.com/shu223/items/2e493645e2d9a1e35a0d
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &textureCache)
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        
        var metalTexture: CVMetalTexture?
        
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, buffer, nil, colorPixelFormat, width, height, 0, &metalTexture)
        
        if result != kCVReturnSuccess {
            return
        }
        
        imageTexture = CVMetalTextureGetTexture(metalTexture!)
        drawableSize = CGSize(width: width, height: height)
    }
    
    public func snapshot() -> UIImage {
        let texture = currentDrawable?.texture
        
        let width: Int = (texture?.width)!
        let height: Int = (texture?.height)!
        let rowBytes = width * 4
        let data = malloc(width * height * 4)
        
        texture?.getBytes(data!, bytesPerRow: rowBytes, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little)
        
        let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        let imageRef = context!.makeImage()
        
        return UIImage(cgImage: imageRef!)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // @see https://developer.apple.com/library/content/samplecode/MetalShaderShowcase/Listings/MetalShaderShowcase_AAPLRenderer_mm.html
        semaphore.wait()
        
        guard
            let texture = imageTexture,
            let drawable = currentDrawable,
            let commandBuffer = commandQueue?.makeCommandBuffer(),
            let descriptor = currentRenderPassDescriptor
        else {
            return
        }
        
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder.setRenderPipelineState(pipeline!)
        encoder.setFragmentTexture(texture, at: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            self.semaphore.signal()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
