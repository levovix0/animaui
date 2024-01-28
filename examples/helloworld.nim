import animaui

let firaCode = useFont "FiraCode"

byTime 0's:
  addToScene:
    - UiRect():
      this.fill parent
      this.color[] = "202020"

    - Code() as code:
      this.centerIn parent

      # this.syntaxHighlignting[] = nim
      this.font[] = firaCode(3.pt)

      this.text[] = """
        echo "hello animaui!"
        if you.like(it):
          please star_this_repo()
      """.stripCode

      this.textAutoConstruct(
        lineByLine, timepoint,
        total = 2's, pauseTotal = 1's,
        slideUp=0.1.h
      )
    
    - UiRect() as rect:
      this.h[] = 0.2.pt
      this.centerX = parent.center
      this.top = code.bottom + 1.pt
      
      this.color[] = "808080"

    afterTime 2's:
      change rect.w[]: code.w[]

    afterTime 2's:
      for x in code.textObj[].childs:
        x.UiText.disappear(slideUp = 0.1.h)

      rect.disappear()

    afterTime 1's:
      finish()


render()

