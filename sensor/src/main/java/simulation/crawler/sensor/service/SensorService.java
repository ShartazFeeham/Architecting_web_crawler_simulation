package simulation.crawler.sensor.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import simulation.crawler.sensor.dto.SensorResponse;

import java.util.Random;

@Service
@Slf4j
public class SensorService {
    private final Random random = new Random();

    @Value("${sensor.jitter.min:100}")
    private int minJitter;

    @Value("${sensor.jitter.max:300}")
    private int maxJitter;

    @Value("${sensor.fail-rate:0.25}")
    private double failRate;

    public SensorResponse inspect(String url) throws Exception {
        log.info("Received inspection request for URL: {}", url);

        // Simulation: Jitter
        int jitter = minJitter + random.nextInt(maxJitter - minJitter);
        log.info("Simulating inspection delay: {}ms for URL: {}", jitter, url);
        Thread.sleep(jitter);

        // Simulation: Failure Rate
        if (random.nextDouble() < failRate) {
            log.error("Simulated sensor failure for URL: {}", url);
            throw new RuntimeException("Simulated Sensor Failure");
        }

        SensorResponse response = new SensorResponse();
        response.setSslStatus(random.nextBoolean() ? "VALID" : "INVALID");
        response.setLatencyMs((long) jitter);
        response.setSiteAvailable(true);
        response.setCensored(random.nextDouble() < 0.25); // 25% censorship rate

        log.info("Successfully inspected URL: {} (Censored: {})", url, response.getCensored());
        return response;
    }
}
