package simulation.crawler.processor.entity;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import simulation.crawler.processor.dto.ParserData;
import simulation.crawler.processor.dto.SensorData;

import java.io.Serializable;

@Entity
@Table(name = "crawl_records")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CrawlRecord implements Serializable {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String url;

    @Column(nullable = false)
    private Long processId;

    @Column(nullable = false)
    private String status; // PENDING, COMPLETED, FAILED

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private ParserData parsingData;

    private Boolean censored;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private SensorData sensorData;
}
