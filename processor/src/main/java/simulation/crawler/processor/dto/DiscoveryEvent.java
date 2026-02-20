package simulation.crawler.processor.dto;

import lombok.Data;

@Data
public class DiscoveryEvent {
    private String url;
    private Long processId;
}
