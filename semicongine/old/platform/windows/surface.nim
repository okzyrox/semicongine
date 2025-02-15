import ../../core
import ../../platform/window

proc CreateNativeSurface*(instance: VkInstance, window: NativeWindow): VkSurfaceKHR =
  assert instance.Valid
  var surfaceCreateInfo = VkWin32SurfaceCreateInfoKHR(
    sType: VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
    hinstance: cast[HINSTANCE](window.hinstance),
    hwnd: cast[HWND](window.hwnd),
  )
  checkVkResult vkCreateWin32SurfaceKHR(instance, addr(surfaceCreateInfo), nil, addr(result))
