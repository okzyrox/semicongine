import std/tables
import std/strformat
import std/logging

import ../core
import ./buffer

type
  Drawable* = object
    name*: string
    elementCount*: int                                                              # number of vertices or indices
    bufferOffsets*: Table[VkPipeline, seq[(string, MemoryPerformanceHint, uint64)]] # list of buffers and list of offset for each attribute in that buffer
    instanceCount*: int                                                             # number of instance
    case indexed*: bool
    of true:
      indexType*: VkIndexType
      indexBufferOffset*: uint64
    of false:
      discard

func `$`*(drawable: Drawable): string =
  if drawable.indexed:
    &"Drawable({drawable.name}, elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, bufferOffsets: {drawable.bufferOffsets}, indexType: {drawable.indexType}, indexBufferOffset: {drawable.indexBufferOffset})"
  else:
    &"Drawable({drawable.name}, elementCount: {drawable.elementCount}, instanceCount: {drawable.instanceCount}, bufferOffsets: {drawable.bufferOffsets})"

proc Draw*(drawable: Drawable, commandBuffer: VkCommandBuffer, vertexBuffers: Table[MemoryPerformanceHint, Buffer], indexBuffer: Buffer, pipeline: VkPipeline) =
  debug &"Draw {drawable} with pipeline {pipeline}"

  var buffers: seq[VkBuffer]
  var offsets: seq[VkDeviceSize]

  for (name, performanceHint, offset) in drawable.bufferOffsets[pipeline]:
    assert vertexBuffers[performanceHint].vk.Valid
    buffers.add vertexBuffers[performanceHint].vk
    offsets.add VkDeviceSize(offset)

  debug "Binding buffers: ", buffers
  debug "with offsets ", offsets
  commandBuffer.vkCmdBindVertexBuffers(
    firstBinding = 0'u32,
    bindingCount = uint32(buffers.len),
    pBuffers = buffers.ToCPointer(),
    pOffsets = offsets.ToCPointer()
  )
  if drawable.indexed:
    assert indexBuffer.vk.Valid
    commandBuffer.vkCmdBindIndexBuffer(indexBuffer.vk, VkDeviceSize(drawable.indexBufferOffset), drawable.indexType)
    commandBuffer.vkCmdDrawIndexed(
      indexCount = uint32(drawable.elementCount),
      instanceCount = uint32(drawable.instanceCount),
      firstIndex = 0,
      vertexOffset = 0,
      firstInstance = 0
    )
  else:
    commandBuffer.vkCmdDraw(
      vertexCount = uint32(drawable.elementCount),
      instanceCount = uint32(drawable.instanceCount),
      firstVertex = 0,
      firstInstance = 0
    )
