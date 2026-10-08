# AEB-lite Requirements

## System overview

AEB-lite triggers an emergency brake when a vehicle is moving above threshold speed
and an obstacle is detected within the detection range.
Sensor data older than the timeout is treated as a fault condition.

## Requirements

| ID | Requirement | Expected output |
|---|---|---|
| REQ-01 | Speed ≥ 30 km/h AND obstacle ≤ 20 m AND sensor valid → BRAKE | BRAKE |
| REQ-02 | Speed < 30 km/h → NO_ACTION (regardless of obstacle) | NO_ACTION |
| REQ-03 | Sensor age ≥ 200 ms → FAULT | FAULT |
| REQ-04 | In FAULT, sensor healthy for 1 s → return to NORMAL | NORMAL |
| REQ-05 | Speed outside [0, 250] km/h → FAULT (invalid input) | FAULT |

## Parameters

| Parameter | Value |
|---|---|
| Brake speed threshold | 30 km/h |
| Detection range | 20 m |
| Sensor timeout | 200 ms |
| Valid speed range | 0–250 km/h |

## Design decisions

- **Check order.** Input range (REQ-05) is checked first, then sensor age (REQ-03), then the brake condition (REQ-01). A stale sensor reading therefore never produces BRAKE.
- **Fault latch (REQ-04).** Any FAULT, from a stale sensor or an out-of-range speed, puts the controller in the FAULT state. While latched the output stays FAULT, even if the inputs would otherwise call for BRAKE. After 1000 ms of continuous healthy input the controller returns to NORMAL. A new fault during recovery restarts the 1000 ms.
- **No obstacle.** "Nothing detected" is a distinct input (empty in the CSV, `None` in code), not a distance of zero.
