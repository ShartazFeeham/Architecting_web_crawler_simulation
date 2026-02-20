package simulation.crawler.sensor.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import simulation.crawler.sensor.dto.SensorResponse;
import simulation.crawler.sensor.service.SensorService;

@RestController
@RequestMapping("/api/v1/sensor")
@RequiredArgsConstructor
public class SensorController {
    private final SensorService sensorService;

    @PostMapping("/inspect")
    public SensorResponse inspect(@RequestBody String url) throws Exception {
        return sensorService.inspect(url);
    }
}
