package simulation.crawler.url.discovery.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import simulation.crawler.url.discovery.dto.DiscoveryRequest;
import simulation.crawler.url.discovery.service.DiscoveryService;

@RestController
@RequestMapping("/api/v1/discovery")
@RequiredArgsConstructor
public class DiscoveryController {
    private final DiscoveryService discoveryService;

    @PostMapping("/generate")
    public Long generate(@RequestBody(required = false) DiscoveryRequest request) {
        int count = (request != null) ? request.getCount() : 0;
        return discoveryService.generateUrls(count);
    }
}
