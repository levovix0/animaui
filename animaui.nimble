# Package

version       = "0.1.0"
author        = "levovix0"
description   = "Animation program for making cool lessons"
license       = "MIT"
srcDir        = "src"
bin           = @["animaui/animauiEditor"]


# Dependencies

requires "nim == 2.2.4"
requires "sigui >= 0.2.2"  # for working with graphics/UI
requires "imageman"  # to write image files
requires "cligen"  # for CLI
# requires "ffmpeg"  # to work with video
requires "localize"  # for adding text translations
requires "suru"  # to show progress bar while rendering (in CLI mode)
requires "chronos"  # for cancelable {.async.} procs. Async is used for commands that need to wait for user input
requires "jsony"  # for json serialization
