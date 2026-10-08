# Test cases

The files here are the test design. `tests/` only executes them, so adding a row adds a test.

## aeb_testcases.csv

One row is one test of the stateless decision (REQ-01, 02, 03, 05).

| Column | Meaning |
|---|---|
| `TC_ID` | Unique ID. It becomes the pytest ID. |
| `REQ_ID` | Requirement the case verifies |
| `speed_kph`, `obstacle_m`, `sensor_age_ms` | Inputs. Leave `obstacle_m` empty for "no obstacle detected". |
| `expected` | `BRAKE`, `NO_ACTION` or `FAULT` |
| `priority` | `High` cases also run in the `smoke` set |
| `technique` | `equivalence`, `boundary`, `decision_table` or `state_transition` |

## aeb_sequences.csv

Rows that share a `TC_ID` form one timed sequence for the fault latch (REQ-04). Each row advances the controller by `dt_ms` with the given inputs, then checks `expected`.

Example: a fault, 999 ms of healthy input (still latched), then 1 ms more (recovered).

```
TC_ID,REQ_ID,dt_ms,speed_kph,obstacle_m,sensor_age_ms,expected
TC-31,REQ-04,10,40.0,10.0,200,FAULT
TC-31,REQ-04,999,40.0,10.0,50,FAULT
TC-31,REQ-04,1,40.0,10.0,50,BRAKE
```

## Checking the design

```bash
python -m tools.rtm          # which requirements have test cases
python -m tools.mutation     # which code changes the cases fail to notice
```
