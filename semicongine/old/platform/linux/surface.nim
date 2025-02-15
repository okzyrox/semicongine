import ../../core
import ../../platform/window

proc CreateNativeSurface*(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  assert instance.Valid
  var surfaceCreateInfo = VkXlibSurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    dpy: cast[ptr vulkanapi.Display](window.display),
    window: cast[vulkanapi.Window](window.window),
  )
  checkVkResult vkCreateXlibSurfaceKHR(instance, addr(surfaceCreateInfo), nil, addr(result))
