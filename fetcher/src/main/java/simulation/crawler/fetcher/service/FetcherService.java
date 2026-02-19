package simulation.crawler.fetcher.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import simulation.crawler.fetcher.dto.*;

import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class FetcherService {
    private final ExternalServiceClient client;
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    // Now correctly strictly consumes from the Outbox topic as per architectural
    // detail
    @KafkaListener(topics = "processor.outbox.urls", groupId = "fetcher-group")
    public void consumeNewUrls(String message) {
        try {
            Map<String, Object> event = objectMapper.readValue(message, Map.class);
            String url = (String) event.get("url");

            log.info("Received URL from outbox: {}", url);
            processUrl(url);

        } catch (Exception e) {
            log.error("Failed to process URL event: {}", e.getMessage(), e);
        }
    }

    private void processUrl(String url) throws Exception {
        log.info("Starting enrichment flow for URL: {}", url);

        // 1. Call Parser (No retry)
        log.info("Calling Parser Service for URL: {}", url);
        Optional<ParserResponse> parserOpt = client.callParser(url);

        if (parserOpt.isEmpty()) {
            log.error("Parser failed for URL: {}", url);
            publishResult(url, false, null, null, "Parser failed");
            return;
        }
        log.info("Parser succeeded for URL: {}", url);

        // 2. Call Sensor (1 retry allowed)
        log.info("Calling Sensor Service for URL: {}", url);
        Optional<SensorResponse> sensorOpt = client.callSensor(url, false);
        if (sensorOpt.isEmpty()) {
            log.warn("Sensor failed for {}, initiating retry...", url);
            sensorOpt = client.callSensor(url, true);
        }

        if (sensorOpt.isEmpty()) {
            log.error("Sensor failed after retry for URL: {}", url);
            publishResult(url, false, objectMapper.writeValueAsString(parserOpt.get()), null,
                    "Sensor failed after retry");
            return;
        }
        log.info("Sensor succeeded for URL: {}", url);

        // 3. Complete Success
        log.info("Successfully enriched URL: {}", url);
        publishResult(url, true,
                objectMapper.writeValueAsString(parserOpt.get()),
                sensorOpt.get().getCensored(),
                objectMapper.writeValueAsString(sensorOpt.get()));
    }

    private void publishResult(String url, boolean success, String parsingData, Boolean censored, String sensorData)
            throws Exception {
        FetcherResultEvent result = FetcherResultEvent.builder()
                .url(url)
                .success(success)
                .parsingData(parsingData)
                .censored(censored)
                .sensorData(sensorData)
                .build();

        kafkaTemplate.send("fetcher.results", objectMapper.writeValueAsString(result));
        log.info("Published final results to fetcher.results for URL: {} (Success: {})", url, success);
    }
}
