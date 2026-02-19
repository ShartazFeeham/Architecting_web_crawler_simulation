package simulation.crawler.processor.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import simulation.crawler.processor.dto.*;
import simulation.crawler.processor.entity.CrawlRecord;
import simulation.crawler.processor.repository.CrawlRecordRepository;

@Service
@RequiredArgsConstructor
@Slf4j
public class ProcessorService {
    private final CrawlRecordRepository repository;
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @KafkaListener(topics = "discovery.urls", groupId = "processor-group")
    @Transactional
    public void consumeDiscovery(String message) {
        try {
            DiscoveryEvent event = objectMapper.readValue(message, DiscoveryEvent.class);
            log.info("Received discovery event for URL: {}", event.getUrl());

            if (repository.findByUrl(event.getUrl()).isEmpty()) {
                CrawlRecord record = CrawlRecord.builder()
                        .url(event.getUrl())
                        .processId(event.getProcessId())
                        .status("PENDING")
                        .build();
                repository.save(record);
                log.info("Successfully saved new discovery record to DB: {}", event.getUrl());

                // Simulated Outbox: Publish to 'processor.outbox.urls'
                // This follows the architectural detail in dev_detail.md
                kafkaTemplate.send("processor.outbox.urls", message);
                log.info("Published to outbox for URL: {}", event.getUrl());
            } else {
                log.warn("Duplicate URL detected, skipping: {}", event.getUrl());
            }
        } catch (Exception e) {
            log.error("Error processing discovery event: {}", e.getMessage(), e);
        }
    }

    @KafkaListener(topics = "fetcher.results", groupId = "processor-group")
    @Transactional
    public void consumeResults(String message) {
        try {
            FetcherResult result = objectMapper.readValue(message, FetcherResult.class);
            log.info("Received result for URL: {}, Success: {}", result.getUrl(), result.getSuccess());

            repository.findByUrl(result.getUrl()).ifPresentOrElse(record -> {
                record.setStatus(result.getSuccess() ? "COMPLETED" : "FAILED");

                try {
                    if (result.getParsingData() != null) {
                        record.setParsingData(objectMapper.readValue(result.getParsingData(), ParserData.class));
                    }
                    if (result.getSensorData() != null) {
                        if (result.getSensorData().startsWith("{")) {
                            record.setSensorData(objectMapper.readValue(result.getSensorData(), SensorData.class));
                        } else {
                            SensorData errorData = new SensorData();
                            errorData.setErrorMessage(result.getSensorData());
                            record.setSensorData(errorData);
                        }
                    }
                } catch (Exception e) {
                    log.warn("Could not parse enrichment data for {}: {}", result.getUrl(), e.getMessage());
                }

                record.setCensored(result.getCensored());
                repository.save(record);
                log.info("Successfully updated record for URL: {} with status: {}", result.getUrl(),
                        record.getStatus());
            }, () -> {
                log.error("Received result for unknown URL: {}", result.getUrl());
            });
        } catch (Exception e) {
            log.error("Error processing fetcher result: {}", e.getMessage(), e);
        }
    }
}
