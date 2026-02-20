package simulation.crawler.fetcher.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import simulation.crawler.fetcher.dto.ParserResponse;
import simulation.crawler.fetcher.dto.SensorResponse;

import java.util.Optional;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Service
@RequiredArgsConstructor
@Slf4j
public class ExternalServiceClient {
    private final RestTemplate restTemplate;

    public ExternalServiceClient() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(10000); // 10 seconds connect
        factory.setReadTimeout(15000); // 15 seconds read
        this.restTemplate = new RestTemplate(factory);
    }

    @Value("${parser.url}")
    private String parserUrl;

    @Value("${sensor.url}")
    private String sensorUrl;

    public Optional<ParserResponse> callParser(String url) {
        try {
            log.debug("Calling parser for url: {}", url);
            org.springframework.http.HttpHeaders headers = new org.springframework.http.HttpHeaders();
            headers.setContentType(org.springframework.http.MediaType.TEXT_PLAIN);
            org.springframework.http.HttpEntity<String> request = new org.springframework.http.HttpEntity<>(url,
                    headers);

            ResponseEntity<ParserResponse> response = restTemplate.postForEntity(parserUrl, request,
                    ParserResponse.class);
            return Optional.ofNullable(response.getBody());
        } catch (Exception e) {
            log.warn("Parser call failed for {}: {}", url, e.getMessage());
            return Optional.empty();
        }
    }

    public Optional<SensorResponse> callSensor(String url, boolean isRetry) {
        try {
            log.debug("Calling sensor for url: {}", url + (isRetry ? " (RETRY)" : ""));
            org.springframework.http.HttpHeaders headers = new org.springframework.http.HttpHeaders();
            headers.setContentType(org.springframework.http.MediaType.TEXT_PLAIN);
            org.springframework.http.HttpEntity<String> request = new org.springframework.http.HttpEntity<>(url,
                    headers);

            ResponseEntity<SensorResponse> response = restTemplate.postForEntity(sensorUrl, request,
                    SensorResponse.class);
            return Optional.ofNullable(response.getBody());
        } catch (Exception e) {
            log.warn("Sensor call failed for {}: {}", url, e.getMessage());
            return Optional.empty();
        }
    }
}
