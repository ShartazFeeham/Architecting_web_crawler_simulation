package simulation.crawler.parser.dto;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ParserResponse {
    private String pageTitle;
    private String pageMetaTags;
    private String pageMetaDescription;
    private Integer contentSize;
    private String normalizedContents;
    private Integer popularity;
}
