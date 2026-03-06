package simulation.crawler.fetcher.dto;

public class SensorResponse {
    private String sslStatus;
    private Long latencyMs;
    private Boolean siteAvailable;
    private Boolean censored;

    // Getters and Setters
    public String getSslStatus() {
        return sslStatus;
    }

    public void setSslStatus(String sslStatus) {
        this.sslStatus = sslStatus;
    }

    public Long getLatencyMs() {
        return latencyMs;
    }

    public void setLatencyMs(Long latencyMs) {
        this.latencyMs = latencyMs;
    }

    public Boolean getSiteAvailable() {
        return siteAvailable;
    }

    public void setSiteAvailable(Boolean siteAvailable) {
        this.siteAvailable = siteAvailable;
    }

    public Boolean getCensored() {
        return censored;
    }

    public void setCensored(Boolean censored) {
        this.censored = censored;
    }
}
