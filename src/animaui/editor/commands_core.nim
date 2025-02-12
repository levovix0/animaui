{.used.}

import ./[commands]
import ./commands_core/[add_rect]


proc add_core_commands*(cmds: Commands) =
  cmds.add Command(
    name: "add rect",
    action: command_add_rect,
  )

