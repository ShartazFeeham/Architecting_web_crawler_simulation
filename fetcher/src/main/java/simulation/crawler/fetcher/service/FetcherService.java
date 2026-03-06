package simulation.crawler.fetcher.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;
import simulation.crawler.fetcher.dto.FetcherResultEvent;
import simulation.crawler.fetcher.dto.ParserResponse;
import simulation.crawler.fetcher.dto.SensorResponse;

import java.util.Map;
import java.util.Optional;

@Service
public class FetcherService {
    private static final Logger log = LoggerFactory.getLogger(FetcherService.class);
    private final ExternalServiceClient client;
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public FetcherService(ExternalServiceClient client, KafkaTemplate<String, String> kafkaTemplate) {
        this.client = client;
        this.kafkaTemplate = kafkaTemplate;
    }

    @Value("${kafka.topic.fetcher-results:crawler.fetcher.results}")
    private String fetcherResultsTopic;

    @KafkaListener(topics = "${kafka.topic.public-crawl-records:crawler.public.crawl_records}", groupId = "fetcher-group")
    public void consumeNewUrls(String message) {
        log.info("Received message from outbox Kafka topic");

        try {
            Map<?, ?> event = objectMapper.readValue(message, Map.class);
            Map<?, ?> payload = event.containsKey("payload") ? (Map<?, ?>) event.get("payload") : event;
            Map<?, ?> after = (Map<?, ?>) payload.get("after");
            if (after == null) {
                log.warn("Skipping message because 'after' payload is null (might be a delete event)");
                return;
            }

            // Loop Prevention: Only process if status is PENDING
            String status = (String) after.get("status");
            if (!"PENDING".equalsIgnoreCase(status)) {
                log.debug("Skipping non-PENDING event (Status: {})", status);
                return;
            }

            String url = (String) after.get("url");

            log.info("Received PENDING URL from outbox, spawning Virtual Thread: {}", url);
            Thread.startVirtualThread(() -> {
                try {
                    processUrl(url);
                } catch (Exception ex) {
                    log.error("Virtual Thread failed to process URL: {}", url, ex);
                }
            });

        } catch (Exception e) {
            log.error("Failed to parse URL event from topic: {}", e.getMessage(), e);
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
        FetcherResultEvent result = new FetcherResultEvent(
                url,
                success,
                parsingData,
                censored,
                sensorData);

        kafkaTemplate.send(fetcherResultsTopic, objectMapper.writeValueAsString(result));
        log.info("Published final results to {} for URL: {} (Success: {})", fetcherResultsTopic, url, success);
    }
}
