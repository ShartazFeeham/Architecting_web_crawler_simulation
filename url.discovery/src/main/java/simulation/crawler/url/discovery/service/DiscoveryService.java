package simulation.crawler.url.discovery.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Service;

import java.util.Random;

@Service
@RequiredArgsConstructor
@Slf4j
public class DiscoveryService {
    private final KafkaTemplate<String, String> kafkaTemplate;
    private final Random random = new Random();

    @Value("${discovery.max-count:100000}")
    private int maxCount;

    private static final String[] DOMAINS = { "retail-giant.com", "shop-central.net", "market-hub.io",
            "eco-store.org" };
    private static final String[] CATEGORIES = { "electronics", "apparel", "home", "garden", "toys" };

    public Long generateUrls(int count) {
        log.info("Received request to generate {} URLs", count);
        if (count <= 0)
            count = 100;
        if (count > maxCount)
            count = maxCount;

        long processId = Math.abs(random.nextLong());
        log.info("Starting crawl process: {} for {} URLs", processId, count);
        var startTime = System.currentTimeMillis();

        // Emit events to Kafka directly
        for (int i = 0; i < count; i++) {
            String domain = DOMAINS[random.nextInt(DOMAINS.length)];
            String category = CATEGORIES[random.nextInt(CATEGORIES.length)];
            String url = String.format("https://%s/products/%s/item-%06d", domain, category,
                    Math.abs(random.nextInt(1000000)));

            String event = String.format("{\"url\":\"%s\", \"processId\":%d}", url, processId);
            kafkaTemplate.send("discovery.urls", event);
            log.trace("Published discovery event for URL: {}", url);
        }

        log.info("Successfully published {} discovery events for process ID: {}, time taken: {}ms",
                count, processId, System.currentTimeMillis() - startTime);

        return processId;
    }
}
