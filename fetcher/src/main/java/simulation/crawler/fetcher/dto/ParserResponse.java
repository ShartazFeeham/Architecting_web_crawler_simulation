package simulation.crawler.fetcher.dto;

import lombok.Data;

@Data
public class ParserResponse {
    private String pageTitle;
    private String pageMetaTags;
    private String pageMetaDescription;
    private Integer contentSize;
    private String normalizedContents;
    private Integer popularity;
}
