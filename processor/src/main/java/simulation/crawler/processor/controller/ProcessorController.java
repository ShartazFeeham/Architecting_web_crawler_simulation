package simulation.crawler.processor.controller;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.web.bind.annotation.*;
import simulation.crawler.processor.dto.ProcessorStats;
import simulation.crawler.processor.entity.CrawlRecord;
import simulation.crawler.processor.repository.CrawlRecordRepository;

import java.util.List;

@RestController
@RequestMapping("/api/v1/processor")
public class ProcessorController {
    private final CrawlRecordRepository repository;

    public ProcessorController(CrawlRecordRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/records/{processId}")
    @Cacheable(value = "processRecords", key = "#processId")
    public List<CrawlRecord> getRecordsByProcessId(@PathVariable Long processId) {
        return repository.findByProcessId(processId);
    }

    @GetMapping("/records")
    public List<CrawlRecord> getRecords() {
        return repository.findAll();
    }

    @GetMapping("/stats")
    public ProcessorStats getStats() {
        return new ProcessorStats(
                repository.count(),
                repository.countByStatus("COMPLETED"),
                repository.countByStatus("PENDING"),
                repository.countByStatus("FAILED"),
                repository.countByCensoredTrue());
    }
}
