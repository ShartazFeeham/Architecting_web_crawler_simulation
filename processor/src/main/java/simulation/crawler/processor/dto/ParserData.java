package simulation.crawler.processor.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

import java.io.Serializable;

@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class ParserData implements Serializable {
    private String pageTitle;
    private String pageMetaTags;
    private String pageMetaDescription;
    private Integer contentSize;
    private String normalizedContents;
    private Integer popularity;
}
