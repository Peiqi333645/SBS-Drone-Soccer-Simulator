#include "aero/blade_element.hpp"
#include "control/flight_controller.hpp"

#include <array>
#include <cassert>
#include <cmath>
#include <iostream>

using namespace dronesim;

namespace {
double maximum_thrust_to_weight(double mass, double radius, double kv, double voltage) {
    RotorArray rotors;
    for (int i = 0; i < 4; ++i) {
        RotorConfig cfg;
        cfg.radius = radius;
        cfg.chord = radius * 0.18;
        cfg.hub_radius = radius * 0.12;
        cfg.motor_kv = kv;
        cfg.max_voltage = voltage;
        rotors.add_rotor(cfg);
    }
    const std::array<double, 4> full{1.0, 1.0, 1.0, 1.0};
    rotors.set_throttles(full);
    RigidBodyState body;
    body.mass = mass;
    body.orientation = {0, 0, 0, 1};
    Atmosphere atmosphere;
    Wrench wrench;
    for (int i = 0; i < 3000; ++i)
        wrench = rotors.solve_all(body, atmosphere, {}, 0.00025);
    return wrench.force.y / (mass * 9.80665);
}
}

int main() {
    const auto mixer = MixerMatrix::quad_x();
    const auto neutral = mixer.mix(0.5, 0.0, 0.0, 0.0);
    for (const double motor : neutral)
        assert(std::abs(motor - 0.5) < 1e-12);

    const auto roll = mixer.mix(0.5, 0.1, 0.0, 0.0);
    double collective = 0.0;
    for (const double motor : roll) {
        assert(motor >= 0.0 && motor <= 1.0);
        collective += motor;
    }
    assert(std::abs(collective - 2.0) < 1e-12);

    struct Profile { double mass, radius, kv, voltage; };
    const Profile profiles[] = {
        {0.022, 0.0127, 30000.0, 4.35},
        {0.125, 0.03175, 6000.0, 13.05},
        {0.245, 0.0381, 3800.0, 17.4},
        {0.650, 0.0635, 1950.0, 25.2},
    };
    for (const auto& profile : profiles) {
        const double ratio = maximum_thrust_to_weight(
            profile.mass, profile.radius, profile.kv, profile.voltage);
        assert(std::isfinite(ratio));
        assert(ratio > 1.5 && ratio < 12.0);
    }
    std::cout << "core regression tests passed\n";
}
