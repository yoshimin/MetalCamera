/* 
  Shader.metal
  MetalCamera

  Created by 新谷　よしみ on 2017/02/12.

*/

#include <metal_stdlib>
using namespace metal;

kernel void kernel_passthrough(texture2d<float, access::read> inTexture [[texture(0)]],
                               texture2d<float, access::write> outTexture [[texture(1)]],
                               uint2 gid [[thread_position_in_grid]])
{
    float4 inColor   = inTexture.read(gid);
    outTexture.write(inColor, gid);
}
