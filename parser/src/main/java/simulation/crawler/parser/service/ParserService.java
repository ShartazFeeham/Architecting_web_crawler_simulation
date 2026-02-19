package simulation.crawler.parser.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import simulation.crawler.parser.dto.ParserResponse;

import java.util.Random;

@Service
@Slf4j
public class ParserService {
    private final Random random = new Random();

    @Value("${parser.jitter.min:100}")
    private int minJitter;

    @Value("${parser.jitter.max:1000}")
    private int maxJitter;

    @Value("${parser.fail-rate:0.25}")
    private double failRate;

    public ParserResponse parse(String url) throws Exception {
        log.info("Received parsing request for URL: {}", url);

        // Simulation: Jitter
        int jitter = minJitter + random.nextInt(maxJitter - minJitter);
        log.info("Simulating parsing delay: {}ms for URL: {}", jitter, url);
        Thread.sleep(jitter);

        // Simulation: Failure Rate
        if (random.nextDouble() < failRate) {
            log.error("Simulated parsing failure for URL: {}", url);
            throw new RuntimeException("Simulated Parser Failure");
        }

        ParserResponse response = new ParserResponse();
        response.setPageTitle("Simulated Title for " + url);
        response.setPageMetaTags("crawler, simulation, mock");
        response.setPageMetaDescription("This is a simulated description for the crawled site.");
        response.setContentSize(random.nextInt(50000));
        response.setNormalizedContents("Extracted text from site...");
        response.setPopularity(random.nextInt(100));

        log.info("Successfully parsed URL: {} (Result size: {})", url, response.getContentSize());
        return response;
    }
}
