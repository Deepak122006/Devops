package com.antigravity.devsecops.controller;

import com.antigravity.devsecops.model.ApiResponse;
import com.antigravity.devsecops.service.GreetingService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class GreetingController {

    private final GreetingService greetingService;

    @GetMapping("/hello")
    public ResponseEntity<ApiResponse<String>> hello(
            @RequestParam(defaultValue = "World") String name) {
        String message = greetingService.greet(name);
        return ResponseEntity.ok(ApiResponse.success(message));
    }

    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info() {
        return ResponseEntity.ok(Map.of(
            "app",       "DevSecOps Demo App",
            "version",   "1.0.0",
            "timestamp", Instant.now().toString(),
            "status",    "running"
        ));
    }
}
