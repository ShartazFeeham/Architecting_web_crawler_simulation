package simulation.crawler.processor.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.web.bind.annotation.*;
import simulation.crawler.processor.entity.CrawlRecord;
import simulation.crawler.processor.repository.CrawlRecordRepository;

import java.util.List;

@RestController
@RequestMapping("/api/v1/processor")
@RequiredArgsConstructor
public class ProcessorController {
    private final CrawlRecordRepository repository;

    @GetMapping("/records/{processId}")
    @Cacheable(value = "processRecords", key = "#processId")
    public List<CrawlRecord> getRecordsByProcessId(@PathVariable Long processId) {
        return repository.findByProcessId(processId);
    }
}
