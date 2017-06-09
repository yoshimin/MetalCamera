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
    var library: MTLLibrary?
    var vertexBuffer: MTLBuffer?
    var pipeline: MTLComputePipelineState?
    var textureLoader: MTKTextureLoader?
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        device = MTLCreateSystemDefaultDevice()
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &textureCache)
        
        framebufferOnly = false
        autoResizeDrawable = false
        clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        textureLoader = MTKTextureLoader(device: device!)
        
        commandQueue = device?.makeCommandQueue()
        library = device?.newDefaultLibrary()
        
        guard let function = library?.makeFunction(name: "kernel_passthrough") else {
            fatalError()
        }
        
        pipeline = try! device?.makeComputePipelineState(function: function)
    }
    
    public func setPixelBuffer(_ buffer: CVPixelBuffer) {
        // @see http://qiita.com/shu223/items/2e493645e2d9a1e35a0d
        
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
        
        guard let texture = imageTexture else {
            return
        }
        guard let drawable = currentDrawable else {
            return
        }
        guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
            return
        }
        
        // @see http://qiita.com/shu223/items/3301a1e64757c0bd73ef
        
        let encoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        encoder.setComputePipelineState(pipeline!)
        encoder.setTexture(texture, at: 0)
        encoder.setTexture(drawable.texture, at: 1)
        
        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(width: texture.width / threads.width,
                                   height: texture.height / threads.height,
                                   depth: 1)
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            self.semaphore.signal()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
