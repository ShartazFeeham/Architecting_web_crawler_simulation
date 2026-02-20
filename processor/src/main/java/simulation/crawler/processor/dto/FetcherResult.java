package simulation.crawler.processor.dto;

import lombok.Data;

@Data
public class FetcherResult {
    private String url;
    private Boolean success;
    private String parsingData;
    private Boolean censored;
    private String sensorData;
}
