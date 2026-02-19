package simulation.crawler.parser.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import simulation.crawler.parser.dto.ParserResponse;
import simulation.crawler.parser.service.ParserService;

@RestController
@RequestMapping("/api/v1/parser")
@RequiredArgsConstructor
public class ParserController {
    private final ParserService parserService;

    @PostMapping("/process")
    public ParserResponse process(@RequestBody String url) throws Exception {
        return parserService.parse(url);
    }
}
