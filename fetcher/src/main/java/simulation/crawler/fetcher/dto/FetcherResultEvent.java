package simulation.crawler.fetcher.dto;

import lombok.*;

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
