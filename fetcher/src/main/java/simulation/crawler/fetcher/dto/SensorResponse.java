package simulation.crawler.fetcher.dto;

import lombok.Data;

@Data
public class SensorResponse {
    private String sslStatus;
    private Long latencyMs;
    private Boolean siteAvailable;
    private Boolean censored;
}
