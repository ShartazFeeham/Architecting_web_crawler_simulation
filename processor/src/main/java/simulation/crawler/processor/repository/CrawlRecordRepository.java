package simulation.crawler.processor.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import simulation.crawler.processor.entity.CrawlRecord;

import java.util.List;
import java.util.Optional;

@Repository
public interface CrawlRecordRepository extends JpaRepository<CrawlRecord, Long> {
    Optional<CrawlRecord> findByUrl(String url);
    List<CrawlRecord> findByProcessId(Long processId);
}
