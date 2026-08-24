;;; Color math for deriving one highlight from another.
;;;
;;; This module works in HSL: a hue in degrees, a saturation from 0 to 1, and a
;;; lightness from 0 to 1. HSL remaps the RGB cube into a cylinder, so every
;;; function here does plain arithmetic on the three channels.
;;;
;;; Two more terms appear throughout. The chroma is the gap between the
;;; brightest and the darkest channel, from 0 to 1. The saturation is that gap
;;; as a fraction of the largest chroma that the lightness allows, so a
;;; near-black color reaches a high saturation from a small gap.

(fn to-byte [v]
  "Scale a 0-to-1 decimal channel to a 0-to-255 byte.

  Parameters:
    `v`  The channel value.

  Returns the byte, rounded and clamped to 0 through 255."
  (-> v
      (* 255)
      (+ 0.5)
      (math.floor)
      (math.max 0)
      (math.min 255)))

(fn separate-channels [rgb]
  "Split a 24-bit color into its channels.

  Parameters:
    `rgb`  The 24-bit RGB integer.

  Returns three values: the red, the green and the blue channel, each 0 to 255."
  (let [r (% (math.floor (/ rgb 65536)) 256)
        g (% (math.floor (/ rgb 256)) 256)
        b (% rgb 256)]
    (values r g b)))

(fn max-chroma [l]
  "Find the largest chroma that a lightness allows.

  A channel cannot go above 1 or below 0, so the room for a color to spread
  shrinks as the lightness moves away from the middle. The value is 1 at a
  lightness of 0.5, and falls to 0 at black and at white, which can only be
  grey.

  Parameters:
    `l`  The lightness, 0 to 1.

  Returns the largest chroma, 0 to 1."
  (- 1 (math.abs (- (* 2 l) 1))))

(fn moving-offset [degrees chroma]
  "Find the offset of the channel that moves across a sector.

  The offset rises from 0 to `chroma` across one sector, then falls back to 0
  across the next. It reaches `chroma` at 60, 180 and 300 degrees, which is
  where the color passes through yellow, cyan and magenta.

  Parameters:
    `degrees`  The hue in degrees, 0 to 360.
    `chroma`   The gap between the brightest and the darkest channel, 0 to 1.
               See `max-chroma`.

  Returns the offset, from 0 to `chroma`."
  (let [ramp (% (/ degrees 60) 2)]
    (* chroma (- 1 (math.abs (- ramp 1))))))

(fn sector-channels [degrees chroma moving]
  "Find the channel offsets for one sixth of the hue circle.

  A hue names a position on a circle of six 60-degree sectors. A pure color
  sits at each boundary: red at 0, yellow at 60, green at 120, cyan at 180,
  blue at 240, and magenta at 300. Inside a sector one channel holds its
  brightest value, another holds its darkest, and the third moves between the
  two. That moving channel carries the color from one boundary to the next.

  This function only decides which channel plays which of those three parts. It
  gives the brightest channel `chroma`, the darkest channel 0, and the moving
  channel `moving`. All three are offsets above the darkest channel, so a
  caller raises them by the same amount to reach the lightness it wants.

  Parameters:
    `degrees`  The hue in degrees, 0 to 360.
    `chroma`   The gap between the brightest and the darkest channel, 0 to 1.
               See `max-chroma`.
    `moving`   The offset of the moving channel, from 0 to `chroma`. See
               `moving-offset`.

  Returns three values: the red, the green and the blue offset, each 0 to 1."
  (vim.fn.assert_inrange 0 360 degrees)
  (if (< degrees 60) (values chroma moving 0) ; red to yellow
      (< degrees 120) (values moving chroma 0) ; yellow to green
      (< degrees 180) (values 0 chroma moving) ; green to cyan
      (< degrees 240) (values 0 moving chroma) ; cyan to blue
      (< degrees 300) (values moving 0 chroma) ; blue to magenta
      (<= degrees 360) (values chroma 0 moving) ; magenta to red
      nil))

(fn join-channels [r g b]
  "Combine three channels into a 24-bit color.

  Parameters:
    `r`  The red channel, 0 to 255.
    `g`  The green channel, 0 to 255.
    `b`  The blue channel, 0 to 255.

  Returns the 24-bit RGB integer."
  (+ (* r 65536) (* g 256) b))

(fn hue [r g b]
  "Find the hue of a color.

  Parameters:
    `r`  The red channel, 0 to 1.
    `g`  The green channel, 0 to 1.
    `b`  The blue channel, 0 to 1.

  Returns the hue in degrees, 0 to 360. Returns 0 for a grey, which has no hue."
  (let [brightest (math.max r g b)
        chroma (- brightest (math.min r g b))
        ;; The brightest channel names the pair of sectors that the hue sits
        ;; in, and the other two channels place it within that pair. Each
        ;; sector spans 60 degrees.
        degrees (if (= 0 chroma) 0
                    (= brightest r) (* 60 (/ (- g b) chroma))
                    (= brightest g) (+ 120 (* 60 (/ (- b r) chroma)))
                    (+ 240 (* 60 (/ (- r g) chroma))))]
    (% degrees 360)))

(fn rgb->hsl [rgb]
  "Convert a 24-bit color to hue, saturation and lightness.

  Parameters:
    `rgb`  The 24-bit RGB integer.

  Returns a table:
    `h`  The hue in degrees, 0 to 360.
    `s`  The saturation, 0 to 1.
    `l`  The lightness, 0 to 1."
  (let [(r255 g255 b255) (separate-channels rgb)
        r (/ r255 255)
        g (/ g255 255)
        b (/ b255 255)
        brightest (math.max r g b)
        darkest (math.min r g b)
        chroma (- brightest darkest)
        lightness (/ (+ brightest darkest) 2)
        ;; Saturation is the chroma as a fraction of the most that the
        ;; lightness allows, so the same chroma reads as more saturated the
        ;; closer the color sits to black or to white.
        saturation (if (= 0 chroma) 0 (/ chroma (max-chroma lightness)))
        hue (hue r g b)]
    {:h hue :s saturation :l lightness}))

(fn hsl->rgb [{: h : s : l}]
  "Convert hue, saturation and lightness to a 24-bit color.

  Parameters:
    `hsl`  The color in HSL form.
           `h`  The hue in degrees. This function wraps a value outside 0 to 360.
           `s`  The saturation, 0 to 1.
           `l`  The lightness, 0 to 1.

  Returns the 24-bit RGB integer."
  (let [degrees (% h 360)
        chroma (* (max-chroma l) s)
        moving (moving-offset degrees chroma)
        (r g b) (sector-channels degrees chroma moving)
        darkest (- l (/ chroma 2))
        r* (to-byte (+ r darkest))
        g* (to-byte (+ g darkest))
        b* (to-byte (+ b darkest))]
    (join-channels r* g* b*)))

(fn recolor [rgb saturation lightness]
  "Rebuild a color with the same hue but a new saturation and lightness.

  Parameters:
    `rgb`         The 24-bit RGB integer to take the hue from.
    `saturation`  The new saturation, 0 to 1.
    `lightness`   The new lightness, 0 to 1.

  Returns the 24-bit RGB integer."
  (let [hsl (rgb->hsl rgb)
        hsl* {:h hsl.h :s saturation :l lightness}]
    (hsl->rgb hsl*)))

{: separate-channels : join-channels : rgb->hsl : hsl->rgb : recolor}
