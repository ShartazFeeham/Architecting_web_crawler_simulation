package simulation.crawler.fetcher.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FetcherResultEvent {
    private String url;
    private Boolean success;
    private String parsingData;
    private Boolean censored;
    private String sensorData;
}
