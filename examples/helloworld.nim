import animaui

let comfortaa = useFont "Comfortaa"

ptRatio = 0.05.lwh

by 0's:
  add Rect:
    fill: parent
    color: "202020"

  add Code as code:
    syntaxHighlignting: nim
    text: """
      echo "hello animaui!"

      if you.like(it):
        please star_this_repo()
    """
    font: comfortaa(3.pt)

    centerX: parent.center
    centerY: parent.center

    this.textAutoConstruct(total = 2's, pauseTotal = 0.5's, animation = {slideUp, becomeOpaque})

    after 3's:
      this.disappear({slideDown, becomeTransparent})
  
  add Rect:
    h: 1.px
    centerX: parent
    top: code.bottom + 1.pt
    
    color: "808080"

    after 2's:
      move w: code.w


after 4's:
  finish()


render()
