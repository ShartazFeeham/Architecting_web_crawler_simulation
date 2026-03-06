package simulation.crawler.processor.dto;

public class FetcherResult {
    private String url;
    private Boolean success;
    private String parsingData;
    private Boolean censored;
    private String sensorData;

    public FetcherResult() {
    }

    public String getUrl() {
        return url;
    }

    public void setUrl(String url) {
        this.url = url;
    }

    public Boolean getSuccess() {
        return success;
    }

    public void setSuccess(Boolean success) {
        this.success = success;
    }

    public String getParsingData() {
        return parsingData;
    }

    public void setParsingData(String parsingData) {
        this.parsingData = parsingData;
    }

    public Boolean getCensored() {
        return censored;
    }

    public void setCensored(Boolean censored) {
        this.censored = censored;
    }

    public String getSensorData() {
        return sensorData;
    }

    public void setSensorData(String sensorData) {
        this.sensorData = sensorData;
    }
}
