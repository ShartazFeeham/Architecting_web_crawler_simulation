package simulation.crawler.sensor.dto;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SensorResponse {
    private String sslStatus;
    private Long latencyMs;
    private Boolean siteAvailable;
    private Boolean censored;
}
