/* AEB-lite decision logic, C99. Same behavior as src/aeb.py. */

#ifndef AEB_H
#define AEB_H

#include <stdbool.h>
#include <stdint.h>

typedef float float32_t;

typedef enum
{
    AEB_ACTION_NO_ACTION = 0,
    AEB_ACTION_BRAKE = 1,
    AEB_ACTION_FAULT = 2
} aeb_action_t;

typedef enum
{
    AEB_STATE_NORMAL = 0,
    AEB_STATE_FAULT = 1
} aeb_state_t;

typedef struct
{
    aeb_state_t state;
    uint32_t healthy_ms;
} aeb_controller_t;

/* Stateless decision for one sample (REQ-01, 02, 03, 05).
 * obstacle_m is ignored when obstacle_detected is false. */
aeb_action_t aeb_decide(float32_t speed_kph,
                        bool obstacle_detected,
                        float32_t obstacle_m,
                        uint32_t sensor_age_ms);

void aeb_controller_init(aeb_controller_t *controller);

/* Advances the fault latch of REQ-04 by dt_ms and returns the commanded action.
 * Returns AEB_ACTION_FAULT when controller is NULL. */
aeb_action_t aeb_controller_update(aeb_controller_t *controller,
                                   float32_t speed_kph,
                                   bool obstacle_detected,
                                   float32_t obstacle_m,
                                   uint32_t sensor_age_ms,
                                   uint32_t dt_ms);

#endif /* AEB_H */
