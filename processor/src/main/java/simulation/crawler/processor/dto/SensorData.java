package simulation.crawler.processor.dto;

public class SensorData {
    private String sslStatus;
    private Long latencyMs;
    private Boolean siteAvailable;
    private Boolean censored;
    private String errorMessage;

    public SensorData() {
    }

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

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }
}
