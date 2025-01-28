# Support generic temperature sensors
#
# Changes:
# - Added gcode code to execute if value out of range
#
# Copyright (C) 2025, Alexander K <https://github.com/drA1ex>
#
# Copyright (C) 2019  Kevin O'Connor <kevin@koconnor.net>
#
# This file may be distributed under the terms of the GNU GPLv3 license.


import logging, re

KELVIN_TO_CELSIUS = -273.15


class PrinterSensorGeneric:
    def __init__(self, config):
        self.printer = config.get_printer()
        self.name = config.get_name().split()[-1]
        self.reactor = self.printer.get_reactor()
        self.gcode = self.printer.lookup_object("gcode")
        pheaters = self.printer.load_object(config, 'heaters')
        self.sensor = pheaters.setup_sensor(config)
        self.min_temp = config.getfloat('min_temp', KELVIN_TO_CELSIUS,
                                        minval=KELVIN_TO_CELSIUS)
        self.max_temp = config.getfloat('max_temp', 99999999.9,
                                        above=self.min_temp)

        gcode_macro = self.printer.load_object(config, "gcode_macro")
        self.exceed_gcode_present = config.get("exceed_gcode", None) is not None
        if self.exceed_gcode_present:
            self.exceed_template = gcode_macro.load_template(config, "exceed_gcode")

        self.sensor.setup_minmax(self.min_temp, self.max_temp)
        self.sensor.setup_callback(self.temperature_callback)
        pheaters.register_sensor(config, self)
        self.last_temp = 0.
        self.measured_min = 99999999.
        self.measured_max = 0.

    m112_r = re.compile(r"^(?:[nN][0-9]+)?\s*[mM]112(?:\s|$)", re.MULTILINE)

    def temperature_callback(self, read_time, temp):
        self.last_temp = temp
        if temp:
            self.measured_min = min(self.measured_min, temp)
            self.measured_max = max(self.measured_max, temp)

            if self.exceed_gcode_present and (temp < self.min_temp or temp > self.max_temp):
                template = self.exceed_template.render()
                # Run M112 immediately if present
                if self.m112_r.search(template):
                    self.printer.invoke_shutdown("Shutdown due to sensor value exceeding the limit")
                    return

                self.reactor.register_callback(lambda _: self._exceed_cb(template))
                logging.info(f"[temperature_sensor {self.name}]: Out of range ({temp})")

    def _exceed_cb(self, template):
        try:
            self.gcode.run_script(template)
        except:
            logging.exception(f"[temperature_sensor {self.name}]: Script running error:\n{template}")

    def get_temp(self, eventtime):
        return self.last_temp, 0.

    def stats(self, eventtime):
        return False, '%s: temp=%.1f' % (self.name, self.last_temp)

    def get_status(self, eventtime):
        return {
            'temperature': round(self.last_temp, 2),
            'measured_min_temp': round(self.measured_min, 2),
            'measured_max_temp': round(self.measured_max, 2)
        }


def load_config_prefix(config):
    return PrinterSensorGeneric(config)
