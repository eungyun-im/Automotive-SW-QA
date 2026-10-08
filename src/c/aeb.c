#include "aeb.h"

#include <stddef.h>

#define AEB_SPEED_MIN_KPH (0.0F)
#define AEB_SPEED_MAX_KPH (250.0F)
#define AEB_BRAKE_SPEED_KPH (30.0F)
#define AEB_DETECT_RANGE_M (20.0F)
#define AEB_SENSOR_TIMEOUT_MS (200U)
#define AEB_RECOVERY_MS (1000U)

aeb_action_t aeb_decide(float32_t speed_kph,
                        bool obstacle_detected,
                        float32_t obstacle_m,
                        uint32_t sensor_age_ms)
{
    aeb_action_t action = AEB_ACTION_NO_ACTION;

    /* Written as "in range" so that NaN, which fails every comparison, is a fault. */
    const bool speed_in_range =
        (speed_kph >= AEB_SPEED_MIN_KPH) && (speed_kph <= AEB_SPEED_MAX_KPH);

    if (!speed_in_range)
    {
        action = AEB_ACTION_FAULT;
    }
    else if (sensor_age_ms >= AEB_SENSOR_TIMEOUT_MS)
    {
        action = AEB_ACTION_FAULT;
    }
    else if ((speed_kph >= AEB_BRAKE_SPEED_KPH) && obstacle_detected &&
             (obstacle_m <= AEB_DETECT_RANGE_M))
    {
        action = AEB_ACTION_BRAKE;
    }
    else
    {
        /* No action: initial value stands. */
    }

    return action;
}

void aeb_controller_init(aeb_controller_t *controller)
{
    if (controller != NULL)
    {
        controller->state = AEB_STATE_NORMAL;
        controller->healthy_ms = 0U;
    }
}

aeb_action_t aeb_controller_update(aeb_controller_t *controller,
                                   float32_t speed_kph,
                                   bool obstacle_detected,
                                   float32_t obstacle_m,
                                   uint32_t sensor_age_ms,
                                   uint32_t dt_ms)
{
    aeb_action_t action = AEB_ACTION_FAULT;

    if (controller != NULL)
    {
        const aeb_action_t raw =
            aeb_decide(speed_kph, obstacle_detected, obstacle_m, sensor_age_ms);

        if (raw == AEB_ACTION_FAULT)
        {
            controller->state = AEB_STATE_FAULT;
            controller->healthy_ms = 0U;
        }
        else if (controller->state == AEB_STATE_FAULT)
        {
            /* Saturating add: a long healthy period must not wrap around. */
            if (dt_ms > (UINT32_MAX - controller->healthy_ms))
            {
                controller->healthy_ms = UINT32_MAX;
            }
            else
            {
                controller->healthy_ms += dt_ms;
            }

            if (controller->healthy_ms >= AEB_RECOVERY_MS)
            {
                controller->state = AEB_STATE_NORMAL;
                controller->healthy_ms = 0U;
                action = raw;
            }
        }
        else
        {
            action = raw;
        }
    }

    return action;
}
