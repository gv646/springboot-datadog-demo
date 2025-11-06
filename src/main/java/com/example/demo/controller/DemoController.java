package com.example.demo.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

@RestController
public class DemoController {

    private static final Logger logger = LoggerFactory.getLogger(DemoController.class);
    private final Random random = new Random();

    @GetMapping("/")
    public Map<String, Object> home() {
        logger.info("Home endpoint called");
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Hello from Spring Boot + DataDog POC!");
        response.put("timestamp", LocalDateTime.now().toString());
        response.put("status", "success");
        return response;
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        logger.info("Health check endpoint called");
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("timestamp", LocalDateTime.now().toString());
        return response;
    }

    @GetMapping("/api/test")
    public Map<String, Object> test() {
        logger.info("Test endpoint called - generating some activity");
        
        // Simulate some processing
        try {
            Thread.sleep(random.nextInt(500));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Test endpoint successful");
        response.put("randomValue", random.nextInt(100));
        response.put("timestamp", LocalDateTime.now().toString());
        
        logger.info("Test endpoint completed with random value: {}", response.get("randomValue"));
        return response;
    }

    @PostMapping("/api/metrics")
    public Map<String, Object> triggerMetrics(@RequestBody(required = false) Map<String, Object> payload) {
        logger.info("Metrics endpoint called with payload: {}", payload);
        
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Custom metrics triggered");
        response.put("metricsCount", random.nextInt(10) + 1);
        response.put("timestamp", LocalDateTime.now().toString());
        
        // Log some metric-like information
        logger.info("Generated {} custom metrics", response.get("metricsCount"));
        
        return response;
    }

    @GetMapping("/api/error")
    public Map<String, String> errorTest() {
        logger.error("Error endpoint called - simulating an error");
        throw new RuntimeException("This is a test error for DataDog monitoring");
    }
}
