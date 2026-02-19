package simulation.crawler.fetcher.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import simulation.crawler.fetcher.dto.ParserResponse;
import simulation.crawler.fetcher.dto.SensorResponse;

import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class ExternalServiceClient {
    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${parser.url}")
    private String parserUrl;

    @Value("${sensor.url}")
    private String sensorUrl;

    public Optional<ParserResponse> callParser(String url) {
        try {
            log.debug("Calling parser for url: {}", url);
            ResponseEntity<ParserResponse> response = restTemplate.postForEntity(parserUrl, url, ParserResponse.class);
            return Optional.ofNullable(response.getBody());
        } catch (Exception e) {
            log.warn("Parser call failed for {}: {}", url, e.getMessage());
            return Optional.empty();
        }
    }

    public Optional<SensorResponse> callSensor(String url, boolean isRetry) {
        try {
            log.debug("Calling sensor for url: {}", url + (isRetry ? " (RETRY)" : ""));
            ResponseEntity<SensorResponse> response = restTemplate.postForEntity(sensorUrl, url, SensorResponse.class);
            return Optional.ofNullable(response.getBody());
        } catch (Exception e) {
            log.warn("Sensor call failed for {}: {}", url, e.getMessage());
            return Optional.empty();
        }
    }
}
