package simulation.crawler.processor.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import simulation.crawler.processor.dto.ParserData;
import simulation.crawler.processor.dto.SensorData;

import java.io.Serializable;

@Entity
@Table(name = "crawl_records")
public class CrawlRecord implements Serializable {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String url;

    @Column(nullable = false)
    private Long processId;

    // PENDING, COMPLETED, FAILED
    @Column(nullable = false)
    private String status;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private ParserData parsingData;

    private Boolean censored;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(columnDefinition = "jsonb")
    private SensorData sensorData;

    public CrawlRecord() {
    }

    public CrawlRecord(String url, Long processId, String status) {
        this.url = url;
        this.processId = processId;
        this.status = status;
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getUrl() {
        return url;
    }

    public void setUrl(String url) {
        this.url = url;
    }

    public Long getProcessId() {
        return processId;
    }

    public void setProcessId(Long processId) {
        this.processId = processId;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public ParserData getParsingData() {
        return parsingData;
    }

    public void setParsingData(ParserData parsingData) {
        this.parsingData = parsingData;
    }

    public Boolean getCensored() {
        return censored;
    }

    public void setCensored(Boolean censored) {
        this.censored = censored;
    }

    public SensorData getSensorData() {
        return sensorData;
    }

    public void setSensorData(SensorData sensorData) {
        this.sensorData = sensorData;
    }

    @Override
    public String toString() {
        return "CrawlRecord{" +
                "id=" + id +
                ", url='" + url + '\'' +
                ", processId=" + processId +
                ", status='" + status + '\'' +
                ", censored=" + censored +
                '}';
    }
}
