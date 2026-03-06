package simulation.crawler.fetcher.dto;

public class ParserResponse {
    private String pageTitle;
    private String pageMetaTags;
    private String pageMetaDescription;
    private Integer contentSize;
    private String normalizedContents;
    private Integer popularity;

    // Getters and Setters
    public String getPageTitle() {
        return pageTitle;
    }

    public void setPageTitle(String pageTitle) {
        this.pageTitle = pageTitle;
    }

    public String getPageMetaTags() {
        return pageMetaTags;
    }

    public void setPageMetaTags(String pageMetaTags) {
        this.pageMetaTags = pageMetaTags;
    }

    public String getPageMetaDescription() {
        return pageMetaDescription;
    }

    public void setPageMetaDescription(String pageMetaDescription) {
        this.pageMetaDescription = pageMetaDescription;
    }

    public Integer getContentSize() {
        return contentSize;
    }

    public void setContentSize(Integer contentSize) {
        this.contentSize = contentSize;
    }

    public String getNormalizedContents() {
        return normalizedContents;
    }

    public void setNormalizedContents(String normalizedContents) {
        this.normalizedContents = normalizedContents;
    }

    public Integer getPopularity() {
        return popularity;
    }

    public void setPopularity(Integer popularity) {
        this.popularity = popularity;
    }
}
