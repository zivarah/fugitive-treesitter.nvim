(local {: describe : it} (require :plenary.busted))
(local assert (require :luassert.assert))
(local color (require :fugitive-treesitter.lib.color))

(local tolerance 0.0001)

(describe :separate-channels
          (fn []
            (it "splits a color into its channels"
                (fn []
                  (let [(r g b) (color.separate-channels 0x4a272f)]
                    (assert.equals 74 r)
                    (assert.equals 39 g)
                    (assert.equals 47 b))))
            (it "round-trips through join-channels"
                (fn []
                  (each [_ value (ipairs [0x000000 0xffffff 0x4a272f 0x243e4a])]
                    (let [(r g b) (color.separate-channels value)]
                      (assert.equals value (color.join-channels r g b))))))))

(describe :rgb->hsl
          (fn []
            (it "reads the primaries"
                (fn []
                  (let [red (color.rgb->hsl 0xff0000)
                        green (color.rgb->hsl 0x00ff00)
                        blue (color.rgb->hsl 0x0000ff)]
                    (assert.near 0 red.h tolerance)
                    (assert.near 120 green.h tolerance)
                    (assert.near 240 blue.h tolerance)
                    (assert.near 1 red.s tolerance)
                    (assert.near 0.5 red.l tolerance))))
            (it "gives a grey no saturation"
                (fn []
                  (let [white (color.rgb->hsl 0xffffff)
                        black (color.rgb->hsl 0x000000)
                        grey (color.rgb->hsl 0x808080)]
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
                  (let [hsl (color.rgb->hsl 0x4a272f)]
                    (assert.near 346.29 hsl.h 0.01)
                    (assert.near 0.3097 hsl.s tolerance)
                    (assert.near 0.2216 hsl.l tolerance))))))

(describe :blend
          (fn []
            (it "keeps the color it starts from at 0"
                (fn []
                  (assert.equals 0x4a272f (color.blend 0x4a272f 0x000000 0))))
            (it "reaches the color it moves to at 1"
                (fn []
                  (assert.equals 0x000000 (color.blend 0x4a272f 0x000000 1))))
            (it "meets in the middle at 0.5"
                (fn []
                  (assert.equals 0x808080 (color.blend 0x000000 0xffffff 0.5))))
            (it "moves each channel on its own"
                (fn []
                  ;; Halfway from red to blue keeps no green, and splits the
                  ;; other two channels.
                  (assert.equals 0x800080 (color.blend 0xff0000 0x0000ff 0.5))))
            (it "changes nothing when the two colors match"
                (fn []
                  (assert.equals 0x4a272f (color.blend 0x4a272f 0x4a272f 0.5))))))

(describe :hsl->rgb
          (fn []
            (it "round-trips every hue sector"
                (fn []
                  (each [_ value (ipairs [0xff0000
                                          0xffff00
                                          0x00ff00
                                          0x00ffff
                                          0x0000ff
                                          0xff00ff
                                          0xffffff
                                          0x000000
                                          0x4a272f
                                          0x243e4a])]
                    (assert.equals value
                                   (color.hsl->rgb (color.rgb->hsl value))))))
            (it "wraps a hue outside the circle"
                (fn []
                  (assert.equals (color.hsl->rgb {:h 10 :s 0.5 :l 0.5})
                                 (color.hsl->rgb {:h 370 :s 0.5 :l 0.5}))))
            (it "clamps rather than overflowing"
                (fn []
                  (assert.equals 0xffffff (color.hsl->rgb {:h 0 :s 1 :l 1}))
                  (assert.equals 0x000000 (color.hsl->rgb {:h 0 :s 1 :l 0}))))))
