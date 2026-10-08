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
| REQ-04 | FAULT state → hold for 1 s then return to NORMAL | NORMAL after 1 s |
| REQ-05 | Speed outside [0, 250] km/h → FAULT (invalid input) | FAULT |

## Parameters

| Parameter | Value |
|---|---|
| Brake speed threshold | 30 km/h |
| Detection range | 20 m |
| Sensor timeout | 200 ms |
| Valid speed range | 0–250 km/h |
