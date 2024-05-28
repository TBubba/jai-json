Jai version: beta 0.1.089

Perform tests: Run `jai test.jai -import_dir ./`

Build example: Run `jai first.jai`

Import the library: Copy the `Json` directory to your modules directory.

# TODO

* Test for memory leaks (and if `json_free` actually works).

* Handle errors better ("bubble" an error code to `json_parse`?)

* Validate UTF-8 in strings.

* Test if rounding errors in `string_to_float64` causes any issues?
