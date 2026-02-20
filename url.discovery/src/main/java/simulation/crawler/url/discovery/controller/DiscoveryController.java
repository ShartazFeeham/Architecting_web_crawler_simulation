package simulation.crawler.url.discovery.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import simulation.crawler.url.discovery.service.DiscoveryService;

@RestController
@RequestMapping("/api/v1/discovery")
@RequiredArgsConstructor
public class DiscoveryController {
    private final DiscoveryService discoveryService;

    @PostMapping("/generate")
    public Long generate(@RequestParam(required = false) Integer count) {
        return discoveryService.generateUrls(count);
    }
}
