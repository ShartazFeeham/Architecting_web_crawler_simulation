package simulation.crawler.processor.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

import java.io.Serializable;

@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class SensorData implements Serializable {
    private String sslStatus;
    private Long latencyMs;
    private Boolean siteAvailable;
    private Boolean censored;
    private String errorMessage; // To capture failure reasons
}
