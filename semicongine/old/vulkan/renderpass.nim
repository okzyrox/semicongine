import ../core
import ../material
import ./device
import ./physicaldevice
import ./pipeline
import ./shader
import ./framebuffer

type
  RenderPass* = object
    vk*: VkRenderPass
    device*: Device
    shaderPipelines*: seq[(MaterialType, ShaderPipeline)]
    clearColor*: Vec4f

proc CreateRenderPass*(
  device: Device,
  shaders: openArray[(MaterialType, ShaderConfiguration)],
  clearColor = Vec4f([0.8'f32, 0.8'f32, 0.8'f32, 1'f32]),
  backFaceCulling = true,
  inFlightFrames = 2,
  samples = VK_SAMPLE_COUNT_1_BIT
): RenderPass =
  assert device.vk.Valid

  # some asserts
  for (materialtype, shaderconfig) in shaders:
    shaderconfig.AssertCanRender(materialtype)

  var attachments = @[
      VkAttachmentDescription(
        format: device.physicalDevice.GetSurfaceFormats().FilterSurfaceFormat().format,
        samples: samples,
        loadOp: VK_ATTACHMENT_LOAD_OP_CLEAR,
        storeOp: VK_ATTACHMENT_STORE_OP_STORE,
        stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
        initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
        finalLayout: if samples == VK_SAMPLE_COUNT_1_BIT: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR else: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    ),
    ]

  if samples != VK_SAMPLE_COUNT_1_BIT:
    attachments.add VkAttachmentDescription(
      format: device.physicalDevice.GetSurfaceFormats().FilterSurfaceFormat().format,
      samples: VK_SAMPLE_COUNT_1_BIT,
      loadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      storeOp: VK_ATTACHMENT_STORE_OP_STORE,
      stencilLoadOp: VK_ATTACHMENT_LOAD_OP_DONT_CARE,
      stencilStoreOp: VK_ATTACHMENT_STORE_OP_DONT_CARE,
      initialLayout: VK_IMAGE_LAYOUT_UNDEFINED,
      finalLayout: VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    )

  var
    # dependencies seems to be optional, TODO: benchmark difference
    dependencies = @[VkSubpassDependency(
      srcSubpass: VK_SUBPASS_EXTERNAL,
      dstSubpass: 0,
      srcStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT],
      srcAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
      dstStageMask: toBits [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT],
      dstAccessMask: toBits [VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT, VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT],
    )]
    colorAttachment = VkAttachmentReference(
      attachment: 0,
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )
    resolveAttachment = VkAttachmentReference(
      attachment: 1,
      layout: VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )

  var subpass = VkSubpassDescription(
    flags: VkSubpassDescriptionFlags(0),
    pipelineBindPoint: VK_PIPELINE_BIND_POINT_GRAPHICS,
    inputAttachmentCount: 0,
    pInputAttachments: nil,
    colorAttachmentCount: 1,
    pColorAttachments: addr(colorAttachment),
    pResolveAttachments: if samples == VK_SAMPLE_COUNT_1_BIT: nil else: addr(resolveAttachment),
    pDepthStencilAttachment: nil,
    preserveAttachmentCount: 0,
    pPreserveAttachments: nil,
  )

  var createInfo = VkRenderPassCreateInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
      attachmentCount: uint32(attachments.len),
      pAttachments: attachments.ToCPointer,
      subpassCount: 1,
      pSubpasses: addr(subpass),
      dependencyCount: uint32(dependencies.len),
      pDependencies: dependencies.ToCPointer,
    )
  result.device = device
  result.clearColor = clearColor
  checkVkResult device.vk.vkCreateRenderPass(addr(createInfo), nil, addr(result.vk))

  for (_, shaderconfig) in shaders:
    assert shaderconfig.outputs.len == 1
  for (materialtype, shaderconfig) in shaders:
    result.shaderPipelines.add (materialtype, device.CreatePipeline(result.vk, shaderconfig, inFlightFrames, 0, backFaceCulling = backFaceCulling, samples = samples))

proc BeginRenderCommands*(commandBuffer: VkCommandBuffer, renderpass: RenderPass, framebuffer: Framebuffer, oneTimeSubmit: bool) =
  assert commandBuffer.Valid
  assert renderpass.vk.Valid
  assert framebuffer.vk.Valid
  let
    w = framebuffer.dimension.x
    h = framebuffer.dimension.y

  var clearColors = [VkClearValue(color: VkClearColorValue(float32: renderpass.clearColor))]
  var
    beginInfo = VkCommandBufferBeginInfo(
      sType: VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
      pInheritanceInfo: nil,
      flags: if oneTimeSubmit: VkCommandBufferUsageFlags(VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT) else: VkCommandBufferUsageFlags(0),
    )
    renderPassInfo = VkRenderPassBeginInfo(
      sType: VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
      renderPass: renderPass.vk,
      framebuffer: framebuffer.vk,
      renderArea: VkRect2D(
        offset: VkOffset2D(x: 0, y: 0),
        extent: VkExtent2D(width: w, height: h),
      ),
      clearValueCount: uint32(clearColors.len),
      pClearValues: clearColors.ToCPointer(),
    )
    viewport = VkViewport(
      x: 0.0,
      y: 0.0,
      width: (float)w,
      height: (float)h,
      minDepth: 0.0,
      maxDepth: 1.0,
    )
    scissor = VkRect2D(
      offset: VkOffset2D(x: 0, y: 0),
      extent: VkExtent2D(width: w, height: h)
    )
  checkVkResult commandBuffer.vkResetCommandBuffer(VkCommandBufferResetFlags(0))
  checkVkResult commandBuffer.vkBeginCommandBuffer(addr(beginInfo))
  commandBuffer.vkCmdBeginRenderPass(addr(renderPassInfo), VK_SUBPASS_CONTENTS_INLINE)
  commandBuffer.vkCmdSetViewport(firstViewport = 0, viewportCount = 1, addr(viewport))
  commandBuffer.vkCmdSetScissor(firstScissor = 0, scissorCount = 1, addr(scissor))

proc EndRenderCommands*(commandBuffer: VkCommandBuffer) =
  commandBuffer.vkCmdEndRenderPass()
  checkVkResult commandBuffer.vkEndCommandBuffer()


proc Destroy*(renderPass: var RenderPass) =
  assert renderPass.device.vk.Valid
  assert renderPass.vk.Valid
  renderPass.device.vk.vkDestroyRenderPass(renderPass.vk, nil)
  renderPass.vk.Reset
  for _, pipeline in renderPass.shaderPipelines.mitems:
    pipeline.Destroy()
