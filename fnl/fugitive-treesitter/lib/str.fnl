;;; String helpers.

(fn char-at [s i]
  "Get one character of a string.

  Parameters:
    `s`  The string.
    `i`  The 1-based byte position.

  Returns the character, or an empty string if `i` is past the end of `s`."
  (string.sub s i i))

{: char-at}
