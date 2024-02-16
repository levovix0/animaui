# Package

version       = "0.1.0"
author        = "levovix0"
description   = "Animation program for making cool lessons"
license       = "MIT"
srcDir        = "src"
# bin           = @["animaui/editor"]


# Dependencies

requires "nim >= 2.0.2"
requires "sigui >= 0.1.3"  # для работы с графикой/UI
requires "imageman"  # для записи изображений
requires "cligen"  # для CLI
# requires "ffmpeg"  # для работы с видео
requires "localize"  # для локализации текста
requires "suru"  # для показывание прогресса рендеринга
