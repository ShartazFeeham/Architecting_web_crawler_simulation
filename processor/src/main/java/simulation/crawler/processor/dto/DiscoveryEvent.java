package simulation.crawler.processor.dto;

public class DiscoveryEvent {
    private String url;
    private Long processId;

    public DiscoveryEvent() {
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
}
