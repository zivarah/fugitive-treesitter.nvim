(local {: describe : it} (require :plenary.busted))
(local assert (require :luassert.assert))
(local color (require :fugitive-treesitter.lib.color))

(local tolerance 0.0001)

(fn hex [s]
  "Parse a hex color into a 24-bit integer.

  A hex literal in the source would not survive fnlfmt, which reprints every
  number in decimal, and a decimal color says nothing to a reader.

  Parameters:
    `s`  The six-digit hex string, with no leading `#`.

  Returns the 24-bit RGB integer."
  (tonumber s 16))

(describe :separate-channels
          (fn []
            (it "splits a color into its channels"
                (fn []
                  (let [(r g b) (color.separate-channels (hex :4a272f))]
                    (assert.equals 74 r)
                    (assert.equals 39 g)
                    (assert.equals 47 b))))
            (it "round-trips through join-channels"
                (fn []
                  (each [_ value (ipairs [(hex :000000)
                                          (hex :ffffff)
                                          (hex :4a272f)
                                          (hex :243e4a)])]
                    (let [(r g b) (color.separate-channels value)]
                      (assert.equals value (color.join-channels r g b))))))))

(describe :rgb->hsl
          (fn []
            (it "reads the primaries"
                (fn []
                  (let [red (color.rgb->hsl (hex :ff0000))
                        green (color.rgb->hsl (hex :00ff00))
                        blue (color.rgb->hsl (hex :0000ff))]
                    (assert.near 0 red.h tolerance)
                    (assert.near 120 green.h tolerance)
                    (assert.near 240 blue.h tolerance)
                    (assert.near 1 red.s tolerance)
                    (assert.near 0.5 red.l tolerance))))
            (it "gives a grey no saturation"
                (fn []
                  (let [white (color.rgb->hsl (hex :ffffff))
                        black (color.rgb->hsl (hex :000000))
                        grey (color.rgb->hsl (hex :808080))]
                    (assert.near 0 white.s tolerance)
                    (assert.near 1 white.l tolerance)
                    (assert.near 0 black.s tolerance)
                    (assert.near 0 black.l tolerance)
                    (assert.near 0 grey.s tolerance))))
            (it "reads a muted diff background"
                (fn []
                  ;; A colorscheme's DiffDelete: dark and weakly saturated.
                  ;; Scaling its channels would keep that saturation, which is
                  ;; why a derived color goes through HSL instead.
                  (let [hsl (color.rgb->hsl (hex :4a272f))]
                    (assert.near 346.29 hsl.h 0.01)
                    (assert.near 0.3097 hsl.s tolerance)
                    (assert.near 0.2216 hsl.l tolerance))))))

(describe :hsl->rgb
          (fn []
            (it "round-trips every hue sector"
                (fn []
                  (each [_ value (ipairs [(hex :ff0000)
                                          (hex :ffff00)
                                          (hex :00ff00)
                                          (hex :00ffff)
                                          (hex :0000ff)
                                          (hex :ff00ff)
                                          (hex :ffffff)
                                          (hex :000000)
                                          (hex :4a272f)
                                          (hex :243e4a)])]
                    (assert.equals value
                                   (color.hsl->rgb (color.rgb->hsl value))))))
            (it "wraps a hue outside the circle"
                (fn []
                  (assert.equals (color.hsl->rgb {:h 10 :s 0.5 :l 0.5})
                                 (color.hsl->rgb {:h 370 :s 0.5 :l 0.5}))))
            (it "clamps rather than overflowing"
                (fn []
                  (assert.equals (hex :ffffff)
                                 (color.hsl->rgb {:h 0 :s 1 :l 1}))
                  (assert.equals (hex :000000)
                                 (color.hsl->rgb {:h 0 :s 1 :l 0}))))))
