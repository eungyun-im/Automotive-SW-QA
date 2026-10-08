# Static analysis of the C code

Scope: `src/c/aeb.c` and `src/c/aeb.h`.

## Compiler

Built as C99 with `-Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror`. Any warning fails the build.

## cppcheck

```bash
cppcheck --std=c99 --enable=warning,style,performance,portability --error-exitcode=1 src/c
```

No findings. This step gates CI.

## MISRA C:2012

```bash
cppcheck --std=c99 --addon=misra src/c
```

The cppcheck MISRA addon checks a subset of the guidelines and is not a qualified MISRA checker. Its output is published with every CI run as information. It does not gate the build, because the set of reported rules differs between cppcheck versions.

Findings with cppcheck 2.7:

| Rule | Category | Location | Finding | Disposition |
|---|---|---|---|---|
| 2.5 | Advisory | `aeb.h` include guard `AEB_H` | Macro declared but not used | Deviation. An include guard is defined only to be tested by `#ifndef`. |
| 8.7 | Advisory | `aeb_decide` in `aeb.h` | External linkage, referenced in one translation unit | Deviation. The function is part of the public interface and is called by the test harness and by integrating code. |

## Coding choices made with MISRA in mind

- Fixed-width types (`uint32_t`, `float32_t`) and `bool` from `<stdbool.h>`.
- Unsigned and float literals carry a suffix (`200U`, `30.0F`).
- One exit point per function, and every `if ... else if` chain ends with an `else`.
- Operands of `&&` are parenthesised, with no side effects on the right-hand side.
- No dynamic memory, no recursion, no function-like macros.
- Pointer parameters are checked for `NULL` before use.
- The healthy-time counter saturates at `UINT32_MAX` instead of wrapping.

## Behavior that differs from the Python reference by design

- **Sensor age is unsigned.** A negative age cannot be represented in the C interface. The Python reference accepts it as a small number.
- **Single-precision speed and distance.** Inputs pass through `float`. At the 0.1 resolution of the signals this does not move any value across a threshold, which the back-to-back test confirms on the boundary grid.
- **NaN speed is a fault** in both implementations.
