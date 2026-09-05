class_name RateMath
extends RefCounted

## Betaflight-compatible rate math. Inputs are normalized stick values [-1, 1]
## and outputs are degrees per second. Keep this as the single implementation
## used by both the controller and the UI curve.

static func betaflight(stick: float, rc_rate: float, super_rate: float, expo: float) -> float:
	var command := clampf(stick, -1.0, 1.0)
	var command_abs := absf(command)
	var expo_value := clampf(expo, 0.0, 1.0)
	if expo_value > 0.0:
		command = command * pow(command_abs, 3.0) * expo_value + command * (1.0 - expo_value)
	var adjusted_rc_rate := maxf(rc_rate, 0.0)
	if adjusted_rc_rate > 2.0:
		adjusted_rc_rate += 14.54 * (adjusted_rc_rate - 2.0)
	var angle_rate := 200.0 * adjusted_rc_rate * command
	var super_value := clampf(super_rate, 0.0, 0.99)
	if super_value > 0.0:
		angle_rate /= clampf(1.0 - command_abs * super_value, 0.01, 1.0)
	return clampf(angle_rate, -1998.0, 1998.0)

static func actual(stick: float, center_sensitivity: float, max_rate: float, expo: float) -> float:
	var command := clampf(stick, -1.0, 1.0)
	var command_abs := absf(command)
	var expo_value := clampf(expo, 0.0, 1.0)
	# Mirrors Betaflight applyActualRates(): the second term is even before it
	# is multiplied by the signed stick contribution in the center term.
	var expo_factor := command_abs * (pow(command, 5.0) * expo_value + command * (1.0 - expo_value))
	var center := maxf(center_sensitivity, 0.0)
	var movement := maxf(0.0, max_rate - center)
	return clampf(command * center + movement * expo_factor, -1998.0, 1998.0)

static func degrees_per_second(rate_type: String, stick: float, values: Dictionary) -> float:
	if rate_type == "Actual":
		return actual(stick, float(values.center), float(values.max), float(values.expo))
	return betaflight(stick, float(values.rc), float(values.super), float(values.expo))
