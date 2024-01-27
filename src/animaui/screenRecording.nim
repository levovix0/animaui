import std/importutils
import sigui/uibase, imageman


proc getPixels*(framebuffer: ClipRect, buff: var seq[ColorRgbaU]) =
  privateAccess ClipRect
  let size = framebuffer.prevSize
  buff.setLen size.x * size.y
  glBindTexture(GlTexture2d, framebuffer.tex[0])
  glGetTexImage(GlTexture2d, 0, GlRgba, GlUnsignedInt8888Rev, buff[0].addr)
