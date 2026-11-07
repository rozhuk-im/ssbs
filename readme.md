# Shell Script Build System

Rozhuk Ivan <rozhuk.im@gmail.com> 2026

Shell Script Build System (SSBS) is a lightweight and highly flexible build system written entirely in Bash/Shell Script. SSBS is designed for developers who find established build systems like CMake, Autotools, or Meson to be overly complex, slow, or too heavy for their project's needs, yet still require more power than a standard Makefile can easily provide.\
\
SSBS allows you to define complex build logic declaratively using a set of intuitive shell functions, letting you focus on what you want to build rather than how to invoke the tools.


## Licence
BSD2 licence.


## Donate
Support the author
* **GitHub Sponsors:** [!["GitHub Sponsors"](https://camo.githubusercontent.com/220b7d46014daa72a2ab6b0fcf4b8bf5c4be7289ad4b02f355d5aa8407eb952c/68747470733a2f2f696d672e736869656c64732e696f2f62616467652f2d53706f6e736f722d6661666266633f6c6f676f3d47697448756225323053706f6e736f7273)](https://github.com/sponsors/rozhuk-im) <br/>
* **Buy Me A Coffee:** [!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/rojuc) <br/>
* **PayPal:** [![PayPal](https://srv-cdn.himpfen.io/badges/paypal/paypal-flat.svg)](https://paypal.me/rojuc) <br/>
* **Bitcoin (BTC):** `1AxYyMWek5vhoWWRTWKQpWUqKxyfLarCuz` <br/>


## Features
* llvm and gcc support (any `CC` wrapper works — checks are done by actually compiling)
* POSIX `sh` only — no interpreter beyond `sh` is required, works under bash/csh/sh as well
* pkg-config integration with result caching
* compiler / linker flag detection (`check_c_compiler_flag`, `check_c_linker_flag`),
  with GCC `-Wno-` workaround and optional-one-of flag groups
* `sizeof()` detection (`check_c_type_size`) — result is exported as an env var
* function, symbol and header presence detection
  (`check_c_function_exists`, `check_c_symbol_exists`, `check_c_include_file_exists`) —
  found items auto-add `-DHAVE_<NAME>=1` to `CFLAGS`
* parallel compilation (`xargs -P ${JOBS}`) via the `ssbs_c_compiler.sh` helper
* static libs (`ar` + `ranlib`), shared libs and executables linking
* patches support (`apply_paches`, `restore_files`) with `.orig`/`.rej` cleanup
* `config.h` generation (`config_h_generate`)
* build profiles — per-`BUILD_TYPE` flag sets (debug / release / etc.)
* git distball target (`target_dist_git`, includes submodules)
* macOS (gnutar), FreeBSD (inherits system `CC`/`CFLAGS`/`LDFLAGS` from `make -V`),
  Linux and Windows (Cygwin/MinGW/MSYS) hosts



