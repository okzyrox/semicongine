import ../core
import ./device
import ./image


type
  Framebuffer* = object
    device*: Device
    vk*: VkFramebuffer
    dimension*: Vec2u

proc CreateFramebuffer*(device: Device, renderpass: VkRenderPass, attachments: openArray[ImageView], dimension: Vec2u): Framebuffer =
  assert device.vk.Valid
  assert renderpass.Valid

  result.device = device
  result.dimension = dimension

  var theattachments: seq[VkImageView]
  for a in attachments:
    assert a.vk.Valid
    theattachments.add a.vk
  var framebufferInfo = VkFramebufferCreateInfo(
    sType: VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
    renderPass: renderpass,
    attachmentCount: uint32(theattachments.len),
    pAttachments: theattachments.ToCPointer,
    width: dimension[0],
    height: dimension[1],
    layers: 1,
  )
  checkVkResult device.vk.vkCreateFramebuffer(addr(framebufferInfo), nil, addr(result.vk))

proc Destroy*(framebuffer: var Framebuffer) =
  assert framebuffer.device.vk.Valid
  assert framebuffer.vk.Valid
  framebuffer.device.vk.vkDestroyFramebuffer(framebuffer.vk, nil)
  framebuffer.vk.Reset
