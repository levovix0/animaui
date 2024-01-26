import animaui

let comfortaa = useFont "Comfortaa"

byTime 0's:
  - UiRect() as rkt:
    this.fill parent
    this.color[] = "202020"

  - UiText() as code:
    this.text[] = """echo "hello animaui!""""
    this.font[] = comfortaa(3.pt)

    this.centerIn parent
    this.color[] = "fff"

    this.appear(slideUp=0.2.h)

    afterTime 1's:
      code.disappear()


afterTime 2's:
  finish()

render()
